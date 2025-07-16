import json
import math
import os
import re
from pathlib import Path
from time import sleep, time

import requests as r

save_path = Path(os.path.dirname(os.path.realpath(__file__))) / "data"

file_format = re.compile(r"^search-page(\d+)\.json$")

page = 1

os.makedirs(save_path, exist_ok=True)


def parse_link_header(links):
    # format: <...>; rel="next", <...>; rel="last"
    links = links.split(", ")
    res = {}
    for link in links:
        # very loose parsing, but it is good enough
        parts = link.split('>; rel="')
        rel = parts[1][:-1]
        url = parts[0][1:]
        res[rel] = url
    return res


def parse_rate_limit(headers):
    return {
        "limit": int(headers["x-ratelimit-limit"]),
        "remaining": int(headers["x-ratelimit-remaining"]),
        "reset": int(headers["x-ratelimit-reset"]),
        "resource": headers["x-ratelimit-resource"],
        "used": int(headers["x-ratelimit-used"]),
    }


def request(url, params={}):
    res = r.get(
        url,
        params=params,
        headers={
            "x-github-api-version": "2022-11-28",
            "accept": "application/vnd.github+json",
        },
    )
    if res.status_code != 200:
        # avoid spamming the github api if something goes wrong
        print("Received non-success status code:", res.status_code)
        exit(1)
    data = res.json()
    link_header = res.headers.get("link", default="")
    if link_header:
        links = parse_link_header(link_header)
    else:
        links = {}
    rate_limit = parse_rate_limit(res.headers)
    return {
        "url": url,
        "data": data,
        "links": links,
        "rate_limit": rate_limit,
    }


def build_base_request(max_stars):
    if max_stars:
        if max_stars < 1000:
            return {"url": None, "params": {}}
        q = f"stars:1000..{max_stars} language:python"
    else:
        q = "stars:>1000 language:python"
    return {
        "url": "https://api.github.com/search/repositories",
        "params": {
            "q": q,
            "sort": "stars",
            "order": "desc",
            "per_page": 100,
        },
    }


def get_next_request(res):
    if res["data"]["total_count"] == 0 or res["links"] == {}:
        # finished
        return {"url": None, "params": {}}
    if "next" in res["links"]:
        return {
            "url": res["links"]["next"],
            "params": {},
        }
    else:
        # github only provides up to 1000 results for
        # a single query, so change the query
        min_stars = res["data"]["items"][-1]["stargazers_count"]
        return build_base_request(min_stars)


def try_resume():
    with os.scandir(save_path) as it:
        # (file_name, page_number)
        candidate = (None, -1)
        for entry in it:
            if entry.is_file():
                match = re.match(file_format, entry.name)
                page_num = int(match.group(1))
                if page_num > candidate[1]:
                    candidate = (entry.name, page_num)

        if candidate[0]:
            global page
            page = candidate[1] + 1
            with open(save_path / candidate[0], "r") as f:
                contents = json.loads(f.read())
                return get_next_request(contents)
    return None


next_request = try_resume()
if next_request:
    print("Resumed previous session at page", page)
else:
    next_request = build_base_request(None)

while next_request["url"]:
    res = request(
        next_request["url"],
        params=next_request["params"],
    )
    print(
        f"Fetched page {page} with {len(res['data']['items'])} results (total: {res['data']['total_count']})"
    )

    with open(save_path / f"search-page{page:04d}.json", "w") as f:
        f.write(json.dumps(res))

    next_request = get_next_request(res)

    if res["rate_limit"]["remaining"] == 0:
        seconds_to_reset = math.ceil(res["rate_limit"]["reset"] - time())
        print(f"Hit rate limit. Sleeping for {seconds_to_reset} seconds...")
        sleep(seconds_to_reset)

    sleep(1)
    page += 1

print("Finished!")
