-- Links stored before the scheme allowlist are rendered as href. This clears the ones whose scheme
-- runs script or reads local data: javascript:, vbscript:, data:, file: (case-insensitive).
-- Browsers drop tab/CR/LF anywhere in a URL and leading spaces/control characters, so those are
-- ignored before matching. Everything else is kept untouched: http(s), mailto, scheme-less values
-- and host:port ("meusite.com:8080").
-- What happens to existing rows:
--   * single-link columns: a matching value is set to null.
--   * user_external_links: matching link rows are deleted (other links stay).
--   * link lists kept as one text (developer_profiles.links, corporate_profiles.external_links, entries
--     separated by comma/space/newline): the whole value is set to null when any entry matches.
--     A scheme name inside an entry ("?q=data:x", "metadata:") does not match.
-- Markdown links inside free text are not rewritten here; the front renders legacy ones through
-- its safe-href helper and new ones are refused by the API.
-- [^!-~] is "space, control or non-ASCII"; no backslashes, so MariaDB (PCRE) and H2 (java.util.regex)
-- read the patterns the same way.

update companies set website = null
 where lower(replace(replace(replace(website, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update users set portfolio = null
 where lower(replace(replace(replace(portfolio, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update users set resume_url = null
 where lower(replace(replace(replace(resume_url, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update user_certifications set credential_url = null
 where lower(replace(replace(replace(credential_url, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update community_projects set url = null
 where lower(replace(replace(replace(url, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update community_projects set repo_url = null
 where lower(replace(replace(replace(repo_url, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update user_projects set repo_url = null
 where lower(replace(replace(replace(repo_url, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update games set website_url = null
 where lower(replace(replace(replace(website_url, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update games set support_url = null
 where lower(replace(replace(replace(support_url, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update service_offers set link = null
 where lower(replace(replace(replace(link, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update events set stream_url = null
 where lower(replace(replace(replace(stream_url, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

delete from user_external_links
 where lower(replace(replace(replace(external_link, char(9), ''), char(10), ''), char(13), '')) regexp '^[^!-~]*(javascript|vbscript|data|file):';

update developer_profiles set links = null
 where lower(links) regexp concat('(^|[ ,', char(9), char(10), char(13), '])[^!-~]*(javascript|vbscript|data|file):');

update corporate_profiles set external_links = null
 where lower(external_links) regexp concat('(^|[ ,', char(9), char(10), char(13), '])[^!-~]*(javascript|vbscript|data|file):');
