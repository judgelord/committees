library(tidyverse)
library(here)

repo_url <- "https://github.com/unitedstates/congress-legislators.git"
repo_dir <- here("congress-legislators")
file_path <- "committee-membership-current.yaml"
out_dir <- here("data", "committee-membership-versions")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Clone the repo if it does not exist
if (!dir.exists(file.path(repo_dir, ".git"))) {
  system2("git", c("clone", repo_url, repo_dir))
}

# Fetch latest main
system2(
  "git",
  c("-C", repo_dir, "fetch", "origin", "main")
)

# Get commits that touched the file
commit_log <- system2(
  "git",
  c(
    "-C", repo_dir,
    "log", "origin/main",
    "--follow",
    "--format=%H%x09%cs",
    "--",
    file_path
  ),
  stdout = TRUE
)

commits <- tibble(raw = commit_log) |>
  separate(raw, into = c("sha", "commit_date"), sep = "\t") |>
  mutate(
    short_sha = substr(sha, 1, 7),
    out_file = file.path(
      out_dir,
      paste0("committee-membership-", commit_date, "-", short_sha, ".yaml")
    )
  )

# Save each version
walk2(
  commits$sha,
  commits$out_file,
  function(sha, out_file) {
    message("Saving ", out_file)

    yaml_text <- system2(
      "git",
      c(
        "-C", repo_dir,
        "show",
        paste0(sha, ":", file_path)
      ),
      stdout = TRUE
    )

    writeLines(yaml_text, out_file)
  }
)

commits
