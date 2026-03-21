// Max prompt input in characters (~4 chars ≈ 1 token, 30K chars ≈ 7500 tokens)
const MAX_PROMPT_CHARS = 30_000;

export function stripHtml(html) {
  if (!html) return "";
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(?:p|div|li|tr|h[1-6])>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#\d+;/g, "")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

export function truncate(text, maxChars = 10_000) {
  if (!text || text.length <= maxChars) return text;
  return text.slice(0, maxChars) + "\n... (truncated)";
}

export function cleanField(html, maxChars = 10_000) {
  return truncate(stripHtml(html), maxChars);
}

export function limitPrompt(prompt) {
  if (prompt.length <= MAX_PROMPT_CHARS) return prompt;
  console.warn(`Prompt truncated: ${prompt.length} → ${MAX_PROMPT_CHARS} chars`);
  return prompt.slice(0, MAX_PROMPT_CHARS) + "\n... (truncated)";
}
