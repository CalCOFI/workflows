## Compare eggs -> eggstage,  larvae -> larvaesize, larvaestage

```{r}
#| label: compare_new_eggs_larvae

library(dplyr)
library(glue)
library(readr)
options(readr.show_col_types = F)

dir_csv <- "~/My Drive/projects/calcofi/data/swfsc.noaa.gov/calcofi-db"
# - calcofi-db - Google Drive
#   https://drive.google.com/drive/u/0/folders/13A9yDJCdV0M-lrMLqurzIb3G3ozknr9O

net         <- read_csv(glue("{dir_csv}/net.csv"))
eggs        <- read_csv(glue("{dir_csv}/eggs.csv"))
eggstage    <- read_csv(glue("{dir_csv}/eggstage.csv"))
larvae      <- read_csv(glue("{dir_csv}/larvae.csv"))
larvaesize  <- read_csv(glue("{dir_csv}/larvaesize.csv"))
larvaestage <- read_csv(glue("{dir_csv}/larvaestage.csv"))

net |>
  slice(209) |>
  pull(netid)   # "E61BA79A-CF80-EF11-A099-2CEA7FA0979C" ->"DB8833F2-02EB-EF11-A09E-2CEA7FA0979C

nrow(net)          # old:  76,512
nrow(eggs)         # old:  93,065
nrow(eggstage)     # new:  19,968
nrow(larvae)       # old: 398,124
nrow(larvaesize)   # new: 241,872
nrow(larvaestage)  # new: 114,879

# check old eggs not in new eggstage
eggs |>
  anti_join(
    eggstage,
    by = c("netid", "sppcode")) |>
  nrow() # 93,065, ie ALL, -> 86,228, ie MOST

# check new eggstage not in old eggs
eggstage |>
  anti_join(
    eggs,
    by = c("netid", "sppcode")) |>
  nrow() # 19,968, ie ALL -> 0, ie NONE

# check new eggstage.netid not in old net.net_uuid
eggstage |>
  anti_join(
    net,
    by = c("netid")) |>
  nrow() # 19,968, ie ALL -> 0, ie NONE

# check old larvae not in new larvaesize
larvae |>
  anti_join(
    larvaesize,
    by = c("netid", "sppcode")) |>
  nrow() # 398,124, ie ALL -> 343,757, ie MOST

# check new larvaesize not in old larvae
larvaesize |>
  anti_join(
    larvae,
    by = c("netid", "sppcode")) |>
  nrow() # 241,872, ie ALL -> 0, ie NONE

# check new larvaestage not in old larvae
larvaestage |>
  anti_join(
    larvae,
    by = c("netid", "sppcode")) |>
  nrow() # 114,879, ie ALL -> 0, ie NONE

# check old larvae.netid not in old net.net_uuid
larvae |>
  anti_join(
    net,
    by = c("netid")) |>
  nrow() # 0, ie NONE

# check new larvaesize.netid not in old net.net_uuid
larvaesize |>
  anti_join(
    net,
    by = c("netid")) |>
  nrow() # 241,872, ie ALL -> 0, ie NONE

# check new larvaestage.netid not in old net.net_uuid
larvaestage |>
  anti_join(
    net,
    by = c("netid")) |>
  nrow() # 114,879, ie ALL
```
