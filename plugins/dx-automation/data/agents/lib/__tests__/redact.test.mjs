import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { redact, redactObject, isAllowlisted } from "../redact.js";

describe("redact()", () => {
  it("strips password values", () => {
    assert.equal(redact("password=secret123"), "password=[REDACTED]");
    assert.equal(redact('apikey: "mykey123"'), 'apikey: "[REDACTED]"');
    assert.equal(redact("token=abc-def-ghi"), "token=[REDACTED]");
  });

  it("strips email addresses", () => {
    assert.equal(redact("contact user@example.com today"), "contact [EMAIL] today");
  });

  it("strips env var values", () => {
    assert.equal(redact("DB_HOST=prod.db.com"), "DB_HOST=[REDACTED]");
    assert.equal(redact("AWS_SECRET_KEY=abc123"), "AWS_SECRET_KEY=[REDACTED]");
  });

  it("strips URL auth params", () => {
    assert.equal(
      redact("https://api.com?token=abc123&other=ok"),
      "https://api.com?token=[REDACTED]&other=ok",
    );
    assert.equal(
      redact("https://api.com?auth=secret"),
      "https://api.com?auth=[REDACTED]",
    );
  });

  it("strips JWT tokens", () => {
    const jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U";
    assert.equal(redact(`Bearer ${jwt}`), "Bearer [JWT]");
  });

  it("strips PEM private keys", () => {
    const pem = "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...\n-----END RSA PRIVATE KEY-----";
    assert.equal(redact(pem), "[PRIVATE_KEY]");
  });

  it("strips connection strings", () => {
    assert.equal(redact("jdbc:mysql://host:3306/db"), "[CONNECTION_STRING]");
    assert.equal(redact("mongodb+srv://user:pass@cluster.net/db"), "[CONNECTION_STRING]");
    assert.equal(redact("redis://localhost:6379"), "[CONNECTION_STRING]");
  });

  it("truncates method bodies >10 lines", () => {
    const lines = Array.from({ length: 15 }, (_, i) => `  line${i + 1};`);
    const body = `function foo() {\n${lines.join("\n")}\n}`;
    const result = redact(body);
    assert.ok(result.includes("[TRUNCATED"), `Should contain [TRUNCATED]: ${result}`);
    assert.ok(!result.includes("line15"), "Should not contain line15");
  });
});

describe("redactObject()", () => {
  it("preserves allowlisted content", () => {
    const obj = { filePath: "/src/Main.java", timestamp: "2024-01-01", runId: "abc-123" };
    const result = redactObject(obj);
    assert.deepEqual(result, obj);
  });

  it("handles nested objects", () => {
    const obj = { outer: { inner: "password=x", filePath: "/ok" } };
    const result = redactObject(obj);
    assert.equal(result.outer.inner, "password=[REDACTED]");
    assert.equal(result.outer.filePath, "/ok");
  });
});

describe("isAllowlisted()", () => {
  it("returns true for allowlisted keys", () => {
    assert.ok(isAllowlisted("filePath"));
    assert.ok(isAllowlisted("runId"));
    assert.ok(isAllowlisted("promptHash"));
  });

  it("returns false for non-allowlisted keys", () => {
    assert.ok(!isAllowlisted("password"));
    assert.ok(!isAllowlisted("email"));
    assert.ok(!isAllowlisted("description"));
  });
});
