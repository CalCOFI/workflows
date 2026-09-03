# Follow-on — generic `publish_to-obis.qmd` over the core

`publish_ichthyo_to-obis.qmd` is the last per-dataset publish notebook: it reads the
`swfsc_ichthyo` source tables directly (`tbl_ichthyo`, `net_uuid`, `species_id`, the `lookup`
stage tables) and hand-builds the Event / Occurrence / eMoF triple, which is why nine other bio
datasets have no OBIS route at all. Everything it hand-builds now exists generically: `sample`'s
adjacency list *is* the Event core (`sample_key` → `eventID`, `parent_sample_key` →
`parentEventID`, `depth_min_m`/`depth_max_m` → `minimum/maximumDepthInMeters`,
`volume_sampled_m3` → `sampleSizeValue`), `obs_bio` *is* the Occurrence extension carrying the
denominator (`density_per_10m2` / `density_per_1000m3` → `organismQuantity` +
`organismQuantityType`, `taxon_key` → `scientificNameID`), `obs_attribute` and
`sample_measurement` *are* the two eMoF grains, and WS-H2 put the vocabulary ids the exporter
was missing into the registries the release already publishes — `measurement_type.nerc_p01` /
`units_nerc_p06` (`measurementTypeID` / `measurementUnitID`), `metadata/life_stage.csv`
(`lifeStage` + NERC S11), `metadata/gear.csv` (`samplingProtocol` + NERC L22),
`field_dictionary.dwc_term`. So the work is: generalise the notebook to
`publish_to-obis.qmd` over `cc_get_db()` + the catalog (the `publish_obis_template.qmd`
scaffold and the generic `publish_to-netcdf` / `publish_to-erddap` pair are the pattern),
parameterised by `dataset_key`, emitting `occurrenceStatus` honestly (**ichthyo `obs` is
positive-only** — a surveyed-empty tow has no row, so absences must come from
`sample_root` minus the positives, not from zero rows), and decide with Ben which datasets
publish to OBIS, under which licence, and whether CalCOFI registers one IPT resource per
dataset or one for the programme. Not this release: it changes nothing in the release itself,
and it needs a provider conversation about republishing datasets whose OBIS records SWFSC
already owns.
