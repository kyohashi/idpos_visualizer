# --- .Rprofile ---
source("renv/activate.R")

if (interactive() && Sys.getenv("TERM_PROGRAM") == "vscode") {
  if (requireNamespace("httpgd", quietly = TRUE)) {
    httpgd::hgd(silent = TRUE)
    options(device = "httpgd")
    options(vsc.plot = FALSE)

    httpgd::hgd_browse()

    message("✅ httpgd engine started. Port forwarding may be required.")
  }
}