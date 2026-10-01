# verify_phyto_aphia.R ----
# Re-check metadata/calcofi/phytoplankton/taxon_worms.csv against the WoRMS REST
# API (https://www.marinespecies.org/rest/). The cache is hand-resolved (Q05, Q09),
# so this is the reproducible record of what "every AphiaID was checked" means.
#
#   Rscript libs/verify_phyto_aphia.R           # from the workflows/ root
#
# What it asserts (the script stops, with the offending rows, if any fails):
#  1. every distinct aphia_id exists in WoRMS and is its own accepted id
#     (valid_AphiaID == AphiaID): a taxon_key must be an *accepted* id.
#  2. the cached scientific_name_accepted, rank, kingdom and phylum equal WoRMS's
#     record (a dinoflagellate keyed to a diatom shows up here as a phylum mismatch).
#  3. rank-3 genus coherence ("B7", Ben 2026-10-01): where WoRMS has moved most
#     of the species a source genus names to another accepted genus (Ceratium ->
#     Tripos), every code keyed at that genus keys the ACCEPTED genus, so a
#     hierarchy rollup on that genus agrees with the species items. The source
#     spelling stays verbatim in `species`.
#  4. rank-4 lowest common ancestor: a code counting species of TWO genera
#     together keys the LCA of the two genera in WoRMS's classification, not the
#     class (Dactyliosolen + Guinardia -> Rhizosoleniaceae).
#
# It also prints, without failing, the codes whose AphiaID is NA, so a reviewer
# sees exactly which codes still fall through to a functional-group class.

librarian::shelf(dplyr, glue, here, httr2, jsonlite, purrr, readr, stringr, tibble,
                 quiet = TRUE)

worms_get <- function(path, sleep = 0.15) {
  Sys.sleep(sleep)
  request(paste0("https://www.marinespecies.org/rest/", path)) |>
    req_retry(max_tries = 4, backoff = \(i) 2^i) |>
    req_error(is_error = \(r) FALSE) |>
    req_perform() |>
    (\(r) if (resp_status(r) == 200) fromJSON(resp_body_string(r), simplifyVector = FALSE) else NULL)()
}

# one WoRMS record (NULL when the id does not exist)
worms_record <- function(id) worms_get(glue("AphiaRecordByAphiaID/{id}"))

# classification chain of an AphiaID as a tibble, root first
worms_chain <- function(id) {
  x <- worms_get(glue("AphiaClassificationByAphiaID/{id}"))
  out <- list()
  while (!is.null(x)) {
    out[[length(out) + 1]] <- tibble(aphia_id = x$AphiaID, rank = x$rank, name = x$scientificname)
    x <- x$child
  }
  bind_rows(out)
}

# deepest taxon every chain shares (the lowest common ancestor)
worms_lca <- function(ids) {
  chains <- map(ids, worms_chain)
  common <- reduce(map(chains, "aphia_id"), intersect)
  chains[[1]] |> filter(aphia_id %in% common) |> slice_tail(n = 1)
}

# the ACCEPTED genus of a species record: first word of its valid name
accepted_genus <- function(id) {
  r <- worms_record(id)
  if (is.null(r)) NA_character_ else word(r$valid_name, 1)
}

# the cache ----
cache <- read_csv(here("metadata/calcofi/phytoplankton/taxon_worms.csv"),
                  show_col_types = FALSE)
keyed <- cache |> filter(!is.na(aphia_id))
cat(glue("{nrow(cache)} codes; {nrow(keyed)} keyed, {n_distinct(keyed$aphia_id)} distinct AphiaIDs; ",
         "{sum(is.na(cache$aphia_id))} have no AphiaID"), "\n")

# 1 + 2. each distinct id exists, is accepted-as-itself, and matches the cache ----
ids  <- sort(unique(keyed$aphia_id))
recs <- map(ids, worms_record) |> set_names(ids)
chk  <- tibble(aphia_id = ids) |>
  mutate(
    found    = map_lgl(recs, \(r) !is.null(r)),
    w_name   = map_chr(recs, \(r) r$scientificname %||% NA_character_),
    w_rank   = map_chr(recs, \(r) r$rank %||% NA_character_),
    w_valid  = map_int(recs, \(r) as.integer(r$valid_AphiaID %||% NA_integer_)),
    w_kingdom = map_chr(recs, \(r) r$kingdom %||% NA_character_),
    w_phylum  = map_chr(recs, \(r) r$phylum %||% NA_character_),
    w_status = map_chr(recs, \(r) r$status %||% NA_character_)) |>
  left_join(keyed |> distinct(aphia_id, scientific_name_accepted, rank, kingdom, phylum),
            by = "aphia_id") |>
  mutate(
    id_is_accepted = found & w_valid == aphia_id,
    name_matches   = found & w_name == scientific_name_accepted,
    rank_matches   = found & w_rank == rank,
    tree_matches   = found & w_kingdom == kingdom & w_phylum == phylum)
bad <- chk |> filter(!found | !id_is_accepted | !name_matches | !rank_matches | !tree_matches)
if (nrow(bad)) print(bad, n = Inf, width = Inf)
stopifnot("every AphiaID exists, is its own accepted id, and matches the cached name, rank, kingdom and phylum" = nrow(bad) == 0)
cat(glue("1+2: {nrow(chk)} AphiaIDs exist in WoRMS, are accepted, and match the cached name, rank, kingdom and phylum"), "\n")

# 3. genus coherence (B7) ----
# per source genus: how many of the dataset's species-level codes sit under a
# DIFFERENT accepted genus in WoRMS. "Most" = more than half of at least three.
sp_rows <- keyed |>
  filter(rank != "Genus", str_detect(name_query, "^\\S+ \\S+")) |>
  mutate(src_genus = word(name_query, 1), acc_genus = word(scientific_name_accepted, 1))
moved <- sp_rows |>
  group_by(src_genus) |>
  summarise(n_species = n(), n_moved = sum(acc_genus != src_genus),
            moves_to = names(which.max(table(acc_genus[acc_genus != src_genus]))[1]) %||% NA_character_,
            .groups = "drop") |>
  filter(n_species >= 3, n_moved / n_species > 0.5)
cat("source genera whose species WoRMS has mostly moved elsewhere:\n"); print(moved)

genus_rows <- keyed |> filter(rank == "Genus") |>
  mutate(src_genus = word(species, 1) |> str_remove(",$"))
genus_chk <- genus_rows |>
  inner_join(moved, by = "src_genus") |>
  mutate(ok = scientific_name_accepted == moves_to)
if (nrow(genus_chk)) print(genus_chk |> select(species_code, species, scientific_name_accepted, moves_to, ok), n = Inf)
stopifnot("every genus code of a moved genus keys the accepted genus" = all(genus_chk$ok))
cat(glue("3: {nrow(genus_chk)} genus-level codes of moved genera all key the accepted genus"), "\n")

# 4. two genera counted together -> their lowest common ancestor ----
# components are the GENERA (a species of a pair can be ambiguous in WoRMS, e.g.
# "Guinardia striata" is two records); "pennate a" is an unidentified pennate, so
# it contributes the class Bacillariophyceae (WoRMS has no finer pennate rank
# the source could mean).
lca_codes <- tribble(
  ~species_code, ~components,
  64,  c("Dactyliosolen", "Guinardia"),
  77,  c("Mastogloia", "Bacillariophyceae"),
  619, c("Gyrosigma", "Pleurosigma"))
genus_id <- \(nm) {
  r <- worms_get(glue("AphiaRecordsByName/{URLencode(nm)}?like=false&marine_only=false"))
  r <- keep(r, \(d) identical(d$status, "accepted") && d$rank %in% c("Genus", "Class"))
  if (length(r) != 1) stop(glue("{nm}: expected exactly one accepted genus/class record"))
  r[[1]]$AphiaID
}
lca <- lca_codes |>
  mutate(lca = map(components, \(cc) worms_lca(map_int(cc, genus_id)))) |>
  tidyr::unnest(lca) |>
  left_join(cache |> select(species_code, species, cached_id = aphia_id), by = "species_code") |>
  mutate(ok = cached_id == aphia_id)
print(lca |> select(species_code, species, lca_id = aphia_id, lca_rank = rank, lca_name = name, cached_id, ok))
stopifnot("every two-genus code keys the LCA of its genera" = all(lca$ok))
cat("4: the two-genus codes key their lowest common ancestor\n")

# report: what still falls through to a functional-group class ----
cat("codes with no AphiaID (they key their functional-group class unless overridden):\n")
print(cache |> filter(is.na(aphia_id)) |> select(species_code, taxa, species), n = Inf)
