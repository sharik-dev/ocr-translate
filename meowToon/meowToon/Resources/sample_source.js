// Sample Script for testing meowToon JS Engine (Scraping Akuma.moe)

function fetchPopularSeries(page, callback) {
    nativeLog("JS: Fetching popular series from akuma.moe - page " + page);

    // Use nativeBrowserFetch to handle DDoS-Guard/Cloudflare
    nativeBrowserFetch("https://akuma.moe/", function (html) {
        if (!html) {
            nativeLog("JS: Error - No HTML received (Blocked or Offline)");
            callback([]);
            return;
        }

        nativeLog("JS: HTML received, size: " + html.length);

        // Very basic Regex scraping for Akuma.moe titles and images
        // Pattern: <div class="relative ..."> ... <a href="/manga/..." ... title="..."> ... <img src="..." ...
        const series = [];
        const regex = /<a href="(\/manga\/[^"]+)"[^>]*title="([^"]+)"[^>]*>[\s\S]*?<img src="([^"]+)"/g;

        let match;
        while ((match = regex.exec(html)) !== null) {
            let coverUrl = match[3];
            if (!coverUrl.startsWith("http")) {
                coverUrl = "https://akuma.moe" + coverUrl;
            }

            series.push({
                id: match[1], // e.g., /manga/solo-leveling
                title: match[2],
                cover: coverUrl,
                author: "Unknown",
                description: "Serie scraped from Akuma.moe",
                status: "En cours"
            });
        }

        nativeLog("JS: Scraped " + series.length + " series.");
        callback(series);
    });
}

function searchSeries(query, page, callback) {
    nativeLog("JS: Searching for " + query);
    // Real search would fetch https://akuma.moe/search?q=...
    callback([]);
}

function fetchChapters(mangaId, callback) {
    nativeLog("JS: Fetching chapters for " + mangaId);
    // mangaId is the path like /manga/solo-leveling
    nativeBrowserFetch("https://akuma.moe" + mangaId, function (html) {
        if (!html) {
            callback([]);
            return;
        }

        const chapters = [];
        // Pattern: <a href="(/manga/solo-leveling/[^"]+)" ...
        // <span class="bg-gray-800 ..."> (\d+) </span>
        const regex = /<a href="(\/manga\/[^"]+\/\d+)"[^>]*>[\s\S]*?<span[^>]*>\s*(\d+)\s*<\/span>[\s\S]*?<span[^>]*>(.*?)<\/span>/g;

        let match;
        while ((match = regex.exec(html)) !== null) {
            chapters.push({
                id: match[1],
                name: "Épisode " + match[2] + (match[3] ? " - " + match[3].trim() : ""),
                number: match[2]
            });
        }

        nativeLog("JS: Found " + chapters.length + " chapters.");
        callback(chapters);
    });
}

function fetchPageList(chapterId, callback) {
    nativeLog("JS: Fetching pages for " + chapterId);
    // chapterId is /manga/solo-leveling/10
    nativeBrowserFetch("https://akuma.moe" + chapterId, function (html) {
        if (!html) {
            callback([]);
            return;
        }

        const pages = [];
        // Images are often in data-src or src in a reader div
        // Pattern: <img ... data-src="(https://[^"]+)"
        const regex = /<img[^>]*data-src="([^"]+)"/g;

        let match;
        while ((match = regex.exec(html)) !== null) {
            let imgUrl = match[1];
            if (!imgUrl.startsWith("http")) {
                imgUrl = "https://akuma.moe" + imgUrl;
            }
            pages.push(imgUrl);
        }

        nativeLog("JS: Found " + pages.length + " pages.");
        callback(pages);
    });
}
