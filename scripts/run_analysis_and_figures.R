# Run key analysis and export figures for README.
# Requires: dataset/avocado.csv. Run from project root.

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(tsibble)
  library(feasts)
  library(fable)
  library(fabletools)
  library(scales)
})

# Run from project root: cd "Avocado Project" && Rscript scripts/run_analysis_and_figures.R
if (!file.exists("dataset/avocado.csv")) {
  source("scripts/fetch_or_generate_data.R")
}

avocado_clean <- read_csv("dataset/avocado.csv", show_col_types = FALSE) %>%
  mutate(Date = as.Date(Date), region = as.factor(region), type = as.factor(type)) %>%
  select(Date, AveragePrice, `Total Volume`, `4046`, `4225`, `4770`, type, region) %>%
  rename(average_price = AveragePrice, total_volume = `Total Volume`,
         small_medium_avocado = `4046`, large_avocado = `4225`, extralarge_avocado = `4770`)

avocado_conv <- avocado_clean %>%
  filter(region == "TotalUS", type == "conventional") %>%
  mutate(Week = yearweek(Date)) %>%
  as_tsibble(index = Week)

dir.create("docs/figures", showWarnings = FALSE, recursive = TRUE)

# 1. Price and volume over time
p1 <- avocado_clean %>%
  filter(region == "TotalUS") %>%
  ggplot(aes(Date, average_price, color = type)) +
  geom_line(linewidth = 0.8) +
  scale_color_manual(values = c(conventional = "#2E7D32", organic = "#1565C0")) +
  labs(title = "Average Price Over Time (TotalUS)", x = "Date", y = "Price ($)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
ggsave("docs/figures/readme_price_timeseries.png", p1, width = 7, height = 4, dpi = 150)

p2 <- avocado_clean %>%
  filter(region == "TotalUS") %>%
  ggplot(aes(Date, total_volume / 1e6, color = type)) +
  geom_line(linewidth = 0.8) +
  scale_y_continuous(labels = comma) +
  scale_color_manual(values = c(conventional = "#2E7D32", organic = "#1565C0")) +
  labs(title = "Total Volume Over Time (TotalUS)", x = "Date", y = "Volume (millions)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
ggsave("docs/figures/readme_volume_timeseries.png", p2, width = 7, height = 4, dpi = 150)

# 2. ARIMA forecast
price_ts <- avocado_conv %>% select(Week, average_price)
train_end <- max(price_ts$Week) - 12
train_price <- price_ts %>% filter(Week <= train_end)
test_price <- price_ts %>% filter(Week > train_end)

fit_price <- train_price %>% model(ARIMA(average_price ~ pdq(1, 1, 0)))
f_price <- fit_price %>% forecast(h = 12)

p3 <- f_price %>%
  autoplot(train_price, level = 80) +
  autolayer(test_price, average_price, color = "black", linewidth = 0.8) +
  labs(title = "ARIMA(1,1,0) Price Forecast vs Actual", x = "Week", y = "Price ($)") +
  theme_minimal(base_size = 11)
ggsave("docs/figures/readme_price_forecast.png", p3, width = 7, height = 4, dpi = 150)

# 3. Model comparison bar chart
acc <- accuracy(f_price, test_price)
acc_ses <- train_price %>%
  model(SES = ETS(average_price ~ error("A") + trend("N") + season("N"))) %>%
  forecast(h = 12) %>%
  accuracy(test_price)
acc_naive <- train_price %>%
  model(Naive = NAIVE(average_price)) %>%
  forecast(h = 12) %>%
  accuracy(test_price)

comparison <- tibble(
  Model = c("ARIMA(1,1,0)", "SES", "Naive"),
  MAPE = c(acc$MAPE, acc_ses$MAPE, acc_naive$MAPE)
)

p4 <- ggplot(comparison, aes(x = reorder(Model, -MAPE), y = MAPE, fill = Model == "ARIMA(1,1,0)")) +
  geom_col() +
  geom_text(aes(label = sprintf("%.1f%%", MAPE)), vjust = -0.3, size = 3.5) +
  scale_fill_manual(values = c("TRUE" = "#2E7D32", "FALSE" = "gray70"), guide = "none") +
  labs(title = "Model Comparison: Price MAPE (12-week test)", x = "", y = "MAPE (%)") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))
ggsave("docs/figures/readme_model_comparison.png", p4, width = 6, height = 4, dpi = 150)

# 4. PLU volume forecast accuracy
vol_ts <- avocado_conv %>% select(Week, total_volume)
train_vol <- vol_ts %>% filter(Week <= train_end)
test_vol <- vol_ts %>% filter(Week > train_end)
fit_vol <- train_vol %>% model(ARIMA(total_volume ~ pdq(0, 1, 1)))
f_vol <- fit_vol %>% forecast(h = 12)
acc_vol <- accuracy(f_vol, test_vol)

ts_4046 <- avocado_conv %>% select(Week, small_medium_avocado)
train_4046 <- ts_4046 %>% filter(Week <= train_end)
test_4046 <- ts_4046 %>% filter(Week > train_end)
acc_4046 <- train_4046 %>% model(ARIMA(small_medium_avocado ~ pdq(0, 1, 1))) %>%
  forecast(h = 12) %>% accuracy(test_4046)

ts_4225 <- avocado_conv %>% select(Week, large_avocado)
train_4225 <- ts_4225 %>% filter(Week <= train_end)
test_4225 <- ts_4225 %>% filter(Week > train_end)
acc_4225 <- train_4225 %>% model(ARIMA(large_avocado ~ pdq(0, 1, 1))) %>%
  forecast(h = 12) %>% accuracy(test_4225)

ts_4770 <- avocado_conv %>% select(Week, extralarge_avocado)
train_4770 <- ts_4770 %>% filter(Week <= train_end)
test_4770 <- ts_4770 %>% filter(Week > train_end)
acc_4770 <- train_4770 %>% model(ARIMA(extralarge_avocado ~ pdq(0, 1, 1))) %>%
  forecast(h = 12) %>% accuracy(test_4770)

plu_comparison <- tibble(
  Series = c("Total Volume", "PLU 4046", "PLU 4225", "PLU 4770"),
  MAPE = c(acc_vol$MAPE, acc_4046$MAPE, acc_4225$MAPE, acc_4770$MAPE)
)

p5 <- ggplot(plu_comparison, aes(x = reorder(Series, -MAPE), y = MAPE, fill = MAPE)) +
  geom_col() +
  geom_text(aes(label = sprintf("%.1f%%", MAPE)), vjust = -0.3, size = 3.5) +
  scale_fill_gradient(low = "#E8F5E9", high = "#1B5E20", guide = "none") +
  labs(title = "ARIMA(0,1,1) Forecast MAPE by Series", x = "", y = "MAPE (%)") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))
ggsave("docs/figures/readme_plu_accuracy.png", p5, width = 6, height = 4, dpi = 150)

# 6. Price-volume relationship (TotalUS conventional)
p6 <- avocado_conv %>%
  as_tibble() %>%
  ggplot(aes(average_price, total_volume / 1e6)) +
  geom_point(alpha = 0.5, color = "#2E7D32") +
  geom_smooth(method = "loess", se = TRUE, color = "#1565C0", fill = "#1565C0", alpha = 0.2) +
  scale_y_continuous(labels = comma) +
  labs(title = "Price vs Volume (TotalUS Conventional)", x = "Price ($)", y = "Volume (millions)") +
  theme_minimal(base_size = 11)
ggsave("docs/figures/readme_price_volume.png", p6, width = 6, height = 4, dpi = 150)

# 7. Residual diagnostics
resid_df <- augment(fit_price) %>% filter(!is.na(.innov))
p7 <- ggplot(resid_df, aes(x = .fitted, y = .innov)) +
  geom_point(alpha = 0.5, color = "#2E7D32") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  labs(title = "ARIMA(1,1,0) Residuals vs Fitted", x = "Fitted", y = "Residual") +
  theme_minimal(base_size = 11)
ggsave("docs/figures/readme_residuals.png", p7, width = 6, height = 4, dpi = 150)

message("Figures saved to docs/figures/")
print(comparison)
print(plu_comparison)
