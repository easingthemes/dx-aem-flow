#!/usr/bin/env node
/**
 * DLQ Processor — read, inspect, and manage dead-letter queue messages.
 *
 * Usage:
 *   node eval/process-dlq.js                  # List all DLQ messages
 *   node eval/process-dlq.js --age 24         # Only messages older than 24 hours
 *   node eval/process-dlq.js --delete         # Delete all messages after viewing
 *   node eval/process-dlq.js --requeue        # Re-trigger pipelines for DLQ events
 *   node eval/process-dlq.js --depth          # Just show queue depth
 *
 * Requires: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
 */

import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import path from "path";
import {
  getAwsCredentials,
  getAwsRegion,
  sqsReceive,
  sqsDelete,
  sqsGetQueueAttributes,
} from "../agents/lib/aws-sig.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const infra = JSON.parse(readFileSync(path.join(__dirname, "..", "infra.json"), "utf8"));
const QUEUE_URL = process.env.SQS_DLQ_URL || infra.storage?.sqs?.dlq?.queueUrl;

function parseArgs() {
  const args = process.argv.slice(2);
  return {
    delete: args.includes("--delete"),
    requeue: args.includes("--requeue"),
    depth: args.includes("--depth"),
    age: (() => {
      const idx = args.indexOf("--age");
      return idx >= 0 && args[idx + 1] ? parseInt(args[idx + 1], 10) : null;
    })(),
  };
}

function formatAge(isoTimestamp) {
  const ms = Date.now() - new Date(isoTimestamp).getTime();
  const hours = Math.floor(ms / 3600000);
  if (hours < 1) return `${Math.floor(ms / 60000)}m ago`;
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

async function getDepth(region, credentials) {
  const attrs = await sqsGetQueueAttributes(
    QUEUE_URL,
    ["ApproximateNumberOfMessages", "ApproximateNumberOfMessagesNotVisible"],
    region,
    credentials,
  );
  return {
    visible: parseInt(attrs.ApproximateNumberOfMessages || "0", 10),
    inFlight: parseInt(attrs.ApproximateNumberOfMessagesNotVisible || "0", 10),
  };
}

async function receiveAll(region, credentials) {
  const allMessages = [];
  const seen = new Set();
  let emptyPolls = 0;

  // SQS ReceiveMessage returns up to 10 messages at a time; poll until empty
  while (emptyPolls < 2) {
    const batch = await sqsReceive(QUEUE_URL, 10, 0, region, credentials);
    if (batch.length === 0) {
      emptyPolls++;
      continue;
    }
    emptyPolls = 0;
    for (const msg of batch) {
      if (!seen.has(msg.MessageId)) {
        seen.add(msg.MessageId);
        allMessages.push(msg);
      }
    }
  }

  return allMessages;
}

function parseBody(msg) {
  try {
    return JSON.parse(msg.Body);
  } catch {
    return { raw: msg.Body };
  }
}

async function main() {
  const opts = parseArgs();
  const credentials = getAwsCredentials();
  if (!credentials) {
    console.error("No AWS credentials found. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.");
    process.exit(1);
  }
  if (!QUEUE_URL) {
    console.error("No SQS_DLQ_URL configured and infra.json has no queue URL.");
    process.exit(1);
  }

  const region = getAwsRegion();

  // --depth: just show count
  if (opts.depth) {
    const depth = await getDepth(region, credentials);
    console.log(`DLQ depth: ${depth.visible} messages (${depth.inFlight} in-flight)`);
    process.exit(0);
  }

  console.log("Reading DLQ messages...\n");
  const messages = await receiveAll(region, credentials);

  if (messages.length === 0) {
    console.log("DLQ is empty.");
    process.exit(0);
  }

  // Filter by age
  let filtered = messages;
  if (opts.age) {
    const cutoff = Date.now() - opts.age * 3600000;
    filtered = messages.filter((msg) => {
      const body = parseBody(msg);
      const ts = body.timestamp ? new Date(body.timestamp).getTime() : 0;
      return ts < cutoff;
    });
    console.log(`Filtered to ${filtered.length}/${messages.length} messages older than ${opts.age}h\n`);
  }

  // Display messages
  for (let i = 0; i < filtered.length; i++) {
    const msg = filtered[i];
    const body = parseBody(msg);
    const line = [
      `[${i + 1}/${filtered.length}]`,
      body.pipeline ? `pipeline=${body.pipeline}` : "",
      body.eventId ? `event=${body.eventId}` : "",
      body.timestamp ? formatAge(body.timestamp) : "",
    ].filter(Boolean).join("  ");

    console.log(line);
    if (body.error?.message) {
      console.log(`  error: ${body.error.message}`);
    }
    if (body.runId) {
      console.log(`  runId: ${body.runId}`);
    }
    console.log();
  }

  console.log(`Total: ${filtered.length} message(s)\n`);

  // --delete: remove messages
  if (opts.delete) {
    console.log("Deleting messages...");
    let deleted = 0;
    for (const msg of filtered) {
      try {
        await sqsDelete(QUEUE_URL, msg.ReceiptHandle, region, credentials);
        deleted++;
      } catch (err) {
        console.error(`  Failed to delete ${msg.MessageId}: ${err.message}`);
      }
    }
    console.log(`Deleted ${deleted}/${filtered.length} messages.`);
  }

  // --requeue: log instructions (actual re-triggering requires pipeline-specific logic)
  if (opts.requeue) {
    console.log("Re-queue support: manually trigger the pipeline for each event.");
    console.log("Pipeline IDs from infra.json:");
    for (const [name, p] of Object.entries(infra.pipelines)) {
      console.log(`  ${name}: ${p.id} (${p.name})`);
    }
    console.log("\nUse: az pipelines run --id <PIPELINE_ID> --variables 'WORK_ITEM_ID=<id>'");
  }
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  process.exit(1);
});
