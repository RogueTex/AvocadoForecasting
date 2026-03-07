# Fetch avocado data from Kaggle or generate synthetic data if unavailable.
# Run from project root: source("scripts/fetch_or_generate_data.R")

library(tidyverse)
library(lubridate)

OUT <- "avocado.csv"

# Generate synthetic data matching paper stats (Jan 2015 - Mar 2018)
generate_synthetic <- function() {
  set.seed(42)
  regions <- c("TotalUS", "California", "NewYork", "Texas", "Florida", "Chicago",
    "Philadelphia", "Washington", "Boston", "Atlanta", "Denver", "DallasFtWorth",
    "Detroit", "Houston", "LosAngeles", "Miami", "Northeast", "NorthernNewEngland",
    "Orlando", "PhoenixTucson", "Portland", "Sacramento", "SanDiego", "SanFrancisco",
    "Seattle", "SouthCentral", "SouthCarolina", "StLouis", "Tampa", "West",
    "WestTexNewMexico", "Plains", "GreatLakes", "Midsouth", "Nashville",
    "NewOrleansMobile", "BuffaloRochester", "Charlotte", "Columbus", "GrandRapids",
    "Indianapolis", "Jacksonville", "Louisville", "Memphis", "RaleighGreensboro",
    "RichmondNorfolk", "Roanoke", "Spokane", "Syracuse", "BaltimoreWashington",
    "Boise", "CincinnatiDayton", "HartfordSpringfield", "LasVegas", "MiamiFtLauderdale",
    "NewOrleans")

  dates <- seq(as.Date("2015-01-04"), as.Date("2018-03-25"), by = "week")
  n_weeks <- length(dates)
  n_regions <- min(54, length(regions))

  base_price <- 1.0 + 0.02 * seq_len(n_weeks) / n_weeks + cumsum(rnorm(n_weeks, 0, 0.02))
  base_price <- pmax(0.82, pmin(1.62, base_price))
  base_vol <- 40e6 + 5e6 * sin(2 * pi * seq_len(n_weeks) / 52) + cumsum(rnorm(n_weeks, 0, 1e6))
  base_vol <- pmax(25e6, pmin(65e6, base_vol))

  grid <- expand_grid(Date = dates, region = regions[1:n_regions], type = c("conventional", "organic"))
  grid %>%
    mutate(
      week_idx = match(Date, dates),
      avg_price_base = base_price[week_idx],
      avg_price = avg_price_base * (1 + 0.15 * (type == "organic")) * runif(n(), 0.95, 1.05),
      total_vol_base = base_vol[week_idx],
      total_vol = total_vol_base * runif(n(), 0.3, 1.5),
      vol_4046 = total_vol * runif(n(), 0.2, 0.35),
      vol_4225 = total_vol * runif(n(), 0.2, 0.35),
      vol_4770 = total_vol * runif(n(), 0.01, 0.05),
      year = year(Date)
    ) %>%
    select(Date, AveragePrice = avg_price, `Total Volume` = total_vol,
           `4046` = vol_4046, `4225` = vol_4225, `4770` = vol_4770,
           type, region, year)
}

# Main
if (file.exists(OUT)) {
  message("avocado.csv already exists")
} else {
  message("Generating synthetic data (download avocado.csv from Kaggle for real data).")
  d <- generate_synthetic()
  write_csv(d, OUT)
  message("Wrote ", OUT)
}
