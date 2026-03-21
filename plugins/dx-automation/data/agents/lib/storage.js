/**
 * S3 bundle upload — uploads bundle directory to S3 bucket.
 * Uses AWS SigV4 signing with raw fetch (no npm dependency).
 * Fails open: if not configured or upload fails, logs warning and returns.
 */

import { readFileSync, readdirSync, statSync } from "fs";
import path from "path";
import { getAwsCredentials, getAwsRegion, s3Put } from "./aws-sig.js";

const BUCKET = process.env.S3_BUNDLE_BUCKET;

/**
 * Recursively walk a directory and return relative file paths.
 */
function walkDir(dir, base = dir) {
  const files = [];
  for (const entry of readdirSync(dir)) {
    const full = path.join(dir, entry);
    if (statSync(full).isDirectory()) {
      files.push(...walkDir(full, base));
    } else {
      files.push(path.relative(base, full));
    }
  }
  return files;
}

/**
 * Upload entire bundle directory to S3.
 * @param {string} bundleDir - Local bundle directory path
 * @param {string} runId - Run ID (used as S3 key prefix)
 * @returns {{ uploaded: boolean, blobCount?: number, reason?: string }}
 */
export async function uploadBundle(bundleDir, runId) {
  const credentials = getAwsCredentials();

  if (!credentials) {
    console.log("[Storage] No AWS credentials — skipping bundle upload");
    return { uploaded: false, reason: "not configured" };
  }

  try {
    const region = getAwsRegion();
    const files = walkDir(bundleDir);
    let blobCount = 0;

    for (const relPath of files) {
      const s3Key = `runs/${runId}/${relPath}`;
      const content = readFileSync(path.join(bundleDir, relPath));
      try {
        await s3Put(BUCKET, s3Key, content, "application/octet-stream", region, credentials);
        blobCount++;
      } catch (err) {
        console.warn(`[Storage] Failed to upload ${s3Key}: ${err.message}`);
      }
    }

    console.log(`[Storage] Uploaded ${blobCount}/${files.length} files to s3://${BUCKET}/runs/${runId}/`);
    return { uploaded: true, blobCount };
  } catch (err) {
    console.warn("[Storage] Bundle upload failed:", err.message);
    return { uploaded: false, reason: err.message };
  }
}
