// Parse wiki URL like:
function parseWikiUrl(url) {
  if (!url) return null;
  const m = url.match(/\/([^/]+)\/_wiki\/wikis\/([^/]+)\/(\d+)/);
  if (!m) return null;
  return { project: decodeURIComponent(m[1]), wikiId: m[2], pageId: m[3] };
}

const config = {
  ado: {
    orgUrl: process.env.SYSTEM_COLLECTIONURI,
    project: process.env.SYSTEM_TEAMPROJECT,
    token: process.env.AZURE_DEVOPS_PAT || process.env.SYSTEM_ACCESSTOKEN,
  },
  dorText: process.env.DOR_TEXT || "",
  wiki: parseWikiUrl(process.env.DOR_WIKI_URL),
};

export default config;
