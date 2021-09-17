# Teenage Driving, Mortality, and Risky Behaviors: Public Use Data Repository

[`Overview`](#overview) [`Examples`](#examples) [`Terms of use`](#terms-of-use) [`Update history`](#update-history) 

-----------

## Overview 

This repository contains data and code for:

Huh, Jason and Reif, Julian. "Teenage Driving, Mortality, and Risky Behaviors." *American Economic Review: Insights*, December 2021, 3(4).

It can be used for research, teaching, and replicating published results. The following diagram summarizes the organization of the repository:
```
driving                               # Project folder
├── data                              #   Read-only (input) data
├── processed                         #   Intermediate data
├── results                           #   Output files
|   ├── figures                       #     Figures (PDF)  
|   ├── intermediate                  #     Intermediate results  
|   └── tables                        #     Tables (LaTeX)
├── scripts                           #   Code
|   ├── libraries/stata               #     Add-on Stata packages
|   ├── programs                      #     Auxiliary code called by scripts  
|   ├── 1_import_data.do
|   ├── 2_clean_data.do
|   ├── 3_combine_data.do
|   ├── 4_analysis.do
|   ├── 5_supporting_analysis.do
|   └── 6_tables.do
└── run.do                            #   Master script
```

The included [README](README.pdf) describes the datasets and provides additional details about the analysis. To rerun the analysis from scratch, download this repository, delete the **processed** and **results** folders, and execute the Stata script **run.do**. Note that you need to define the global macro `Driving` on line 18 of **run.do** in order to run the analysis. This macro defines the location of the folder that contains **run.do**.

## Examples

1. Mortality rises by 5.84 deaths per 100,000 at the minimum legal driving age cutoff (see [Table 1, Column 2](https://julianreif.com/research/reif.aeri.2021.driving.pdf))

```stata
***
* Stata code
***
* Load mortality data, convert deaths to death rates per 100,000
use "https://julianreif.com/driving/data/mortality/derived/all.dta", clear
replace cod_any = 100000*cod_any/(pop/12)

* Create indicator for first month of driving eligibility
gen firstmonth = (agemo_mda==0)

* Estimate RD using rdrobust add-on package (ssc install rdrobust, replace)
rdrobust cod_any agemo_mda, covs(firstmonth)
```

```R
###
# R code
###
library(tidyverse)
library(haven)
library(rdrobust)

# Load mortality data, convert deaths to death rates per 100,000
my_data <- read_dta("https://julianreif.com/driving/data/mortality/derived/all.dta")
my_data <- my_data %>% mutate(cod_any = 100000*cod_any/(pop/12))

# Create indicator for first month of driving eligibility
my_data <- my_data %>% mutate(firstmonth = agemo_mda==0)

# Estimate RD using rdrobust add-on package
Y <- my_data$cod_any
X <- my_data$agemo_mda
C <- as.integer(my_data$firstmonth)
summary(rdrobust(Y, X, covs = C))
```

2. Plot average annual vehicle miles traveled for ages 16-19 (see green dashed line in [Figure B.2](https://julianreif.com/research/reif.aeri.2021.driving.pdf))

```stata
***
* Stata code
***
import excel "https://julianreif.com/driving/data/nhts/nhts_1983_2017.xlsx", firstrow clear
format *1619 %12.0fc
label var year "Year"
label var both_1619 "VMT per licensed driver"

local labels "xlabel(1983 1990 1995 2001 2009 2017) ylabel(0(2000)10000, gmax)"
graph twoway connected both_1619 year, graphregion(fcolor(white)) `labels'
```

```R
###
# R code
###
library(openxlsx)
library(tidyverse)

my_data <- read.xlsx("https://julianreif.com/driving/data/nhts/nhts_1983_2017.xlsx")

ggplot(my_data, aes(x=year, y=both_1619)) + geom_line() + geom_point(size=3) + theme_bw() +
  theme(panel.grid.major.x=element_blank(), panel.grid.minor=element_blank()) +
  scale_x_continuous(limits=c(1983, 2017), breaks=c(1983, 1990, 1995, 2001, 2009, 2017), 
    labs(x="Year")) +
  scale_y_continuous(limits=c(0, 10000), breaks=seq(0, 10000, 2000), 
    labels=function(y) format(y, big.mark=","), labs(y="VMT per licensed driver"))

```

## Terms of use

Any materials (books, articles, conference papers, theses, dissertations, reports, and other such publications) created that employ, reference, or otherwise use these data (in whole or in part) should credit this source. Please cite it as:

Huh, J. and Reif, J. "Teenage Driving, Mortality, and Risky Behaviors." *American Economic Review: Insights*, December 2021, 3(4).


## Update history

* **September 13, 2021**
  - Initial release
