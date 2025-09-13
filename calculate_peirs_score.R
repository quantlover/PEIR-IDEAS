# calculate_peirs_score.R — standalone PEIRS scorer
# MIT License (c) 2025 Chi Chang, Sara Santarossa
# -------------------------------------------------------------
# This script provides:
#   - calculate_peirs_score(): main scoring function
#   - summary.peirs_score(): describe-like summary
#   - peirs_items(): helper returning default item names
# -------------------------------------------------------------

# Calculate PEIR-IDEAS scores for each respondent.
# - Input: data.frame with PEIRS item columns (1–5 Likert by default)
# - Output: data.frame with raw total, items answered, standardized 0–100, response flag
calculate_peirs_score <- function(
  data,
  items = c(
    "pr2","pr4","pr7","pr11","pr12","pr13","pr14",
    "t1","t2","t3","t4","t5","t6","t7",
    "su1","su2","su3",
    "be1","be2","be3",
    "cn1","cn2","cn3","cn4",
    "fv1","fv2","fv3"
  ),
  min_items_required = 10,
  scale_from = c(1, 5),
  scale_to   = c(0, 4),
  strict = TRUE
) {
  stopifnot(is.data.frame(data),
            length(scale_from) == 2, length(scale_to) == 2,
            is.numeric(scale_from), is.numeric(scale_to))

  # --- check items ---
  missing_items <- setdiff(items, names(data))
  if (length(missing_items) > 0) {
    msg <- sprintf("Missing items: %s", paste(missing_items, collapse = ", "))
    if (isTRUE(strict)) stop(msg, call. = FALSE) else warning(msg, call. = FALSE)
  }
  present_items <- intersect(items, names(data))
  if (length(present_items) == 0) {
    stop("None of the requested items are present in 'data'.", call. = FALSE)
  }

  # --- prepare data ---
  X <- data[, present_items, drop = FALSE]
  # Coerce to numeric; non-numeric becomes NA
  X[] <- lapply(X, function(col) suppressWarnings(as.numeric(col)))

  # --- rescale (linear map) ---
  a <- scale_from[1]; b <- scale_from[2]
  c0 <- scale_to[1]; d0 <- scale_to[2]
  if (b <= a) stop("'scale_from' must be increasing, e.g., c(1,5).", call. = FALSE)
  span_from <- (b - a); span_to <- (d0 - c0)

  X_rescaled <- as.data.frame(lapply(X, function(x) {
    ifelse(is.na(x), NA_real_, c0 + (x - a) * (span_to / span_from))
  }))

  # --- scoring ---
  raw_total     <- rowSums(X_rescaled, na.rm = TRUE)
  num_answered  <- rowSums(!is.na(X_rescaled))
  max_per_item  <- (scale_to[2] - scale_to[1])
  denom         <- pmax(num_answered * max_per_item, 0)
  standardized  <- ifelse(num_answered > 0, (raw_total / denom) * 100, NA_real_)

  response_flag <- ifelse(num_answered < min_items_required, "Too few items", "Valid")

  out <- data.frame(
    PEIRS_raw_total      = raw_total,
    PEIRS_items_answered = num_answered,
    PEIRS_standardized   = standardized,
    Response_Status      = response_flag,
    stringsAsFactors = FALSE
  )

  # metadata + class
  attr(out, "items_requested") <- items
  attr(out, "items_used")      <- present_items
  attr(out, "items_missing")   <- missing_items
  attr(out, "scale_from")      <- scale_from
  attr(out, "scale_to")        <- scale_to
  class(out) <- c("peirs_score", class(out))

  out
}

# Describe-like summary for PEIRS scores
summary.peirs_score <- function(object, ...) {
  vars <- c("PEIRS_raw_total","PEIRS_items_answered","PEIRS_standardized")
  missing_vars <- setdiff(vars, names(object))
  if (length(missing_vars)) stop(sprintf("Object lacks expected columns: %s", paste(missing_vars, collapse=", ")))

  desc <- sapply(object[vars], function(x) {
    c(
      n      = sum(!is.na(x)),
      mean   = mean(x, na.rm = TRUE),
      sd     = sd(x, na.rm = TRUE),
      min    = suppressWarnings(min(x, na.rm = TRUE)),
      q25    = suppressWarnings(quantile(x, 0.25, na.rm = TRUE)),
      median = median(x, na.rm = TRUE),
      q75    = suppressWarnings(quantile(x, 0.75, na.rm = TRUE)),
      max    = suppressWarnings(max(x, na.rm = TRUE))
    )
  })
  desc <- as.data.frame(t(desc))

  cat("PEIRS Scoring Summary\n")
  cat("Items requested:", length(attr(object,"items_requested")) ,
      "| Items used:", length(attr(object,"items_used")) ,
      "| Missing:", length(attr(object,"items_missing")), "\n\n")
  print(round(desc, 2))
  invisible(desc)
}

# Helper: default item names
peirs_items <- function() {
  c("pr2","pr4","pr7","pr11","pr12","pr13","pr14",
    "t1","t2","t3","t4","t5","t6","t7",
    "su1","su2","su3",
    "be1","be2","be3",
    "cn1","cn2","cn3","cn4",
    "fv1","fv2","fv3")
}
