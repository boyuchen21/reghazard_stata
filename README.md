This readme file describe the three .ado written for the hazard estimator STATA packages.

## 1. **simdata.ado**

**Purpose:**

- Generate a toy dataset for testing your bin‐and‐hazard workflow. This is mostly for internal usage only and we probably don't need it in the released package.

- Draws 10000 observations of a continuous `y` (Normal(15,5)), drops non‐positives.

- Creates two categorical covariates:
  
  - `grp` (string “A”/“B”/“C”)
  
  - `grp2` (numeric 1–5)

- **Syntax:** simply type `simdata` in STATA command window.

---

## 2. **bin_hazard.ado**

**Purpose:**

- Bin a continuous outcome into fixed‐width intervals between a lower and upper bound.

- Optionally stratify by one or more categorical covariates.

- For each covariate-bin cell, compute:
  
  - `_freq` = raw count
  
  - `fweight` = relative frequency (sums to 1 within each covariate group)
  
  - `remain` = reverse cumulative sum of `fweight`. i.e., the share on or above the current bin.
  
  - `hazard` = `fweight/remain` (conditional hazard)

- Enforces a host of sanity checks

- Data are balanced in the sense that, if there's no observation in one bin, I create a row with 0 in fweight.
  
  - However, I don't create rows above the max value in the observations. For example, if upper is 25 but max(y) is 21, I won't create bins with 0 fweight for any bins above 21. //CHECK

- **Syntax:**

`bin_hazard yvar [cov1 cov2 …, lower(real 5) upper(real 25) width(real 0.25)]`

- `yvar` (numeric): outcome to bin

- `cov#` (string or numeric): one or more grouping vars (optional). Can have as many as one wants.

- `lower()`, `upper()`, `width()`: define the lower bound, upper bound, and breaks. (upper - lower) is Restricted to be divisible by width. //CHECK

**Examples:**

```STATA
bin_hazard y //create bin without any covariate segments
bin_hazard y grp //create bin with one covariate
bin_hazard y grp, lower(3) upper(20) width(0.1)
```

---

## 3. **reghazard.ado**

**Purpose:**

- Take the output of **bin_hazard** (with variables `bin`, `fweight`, `hazard`) and fit either:
  
  - **cloglog‐GLM** (`glm fweight i.bin, family(binomial remain) link(cloglog)`) if any `hazard==0`, or
  
  - **OLS** on the transformed outcome (`log(-log(1–hazard))`) otherwise.

- Checks for duplicate (bin×covariate) cells before fitting.

**Syntax:**

`reghazard [cov1 cov2 …] [, keepmin keepmax]`

- `cov#`: optional covariates (for the duplicate‐check).

- `keepmin` / `keepmax`: include the minimum or maximum bin from the regression. Default is to exclude in regression. 
  
  - The function check if the necessary variables are in the data: `bin`, `fweight`, `remain`, `hazard`.
  - The default is to drop the max bin in the binned data. If the original data have observations above `upper` then it'll drop [upper, Inf). However, if all observations are below `upper` (e.g., the user specify a super large upper, ) then the binned data is not top coded and dropping the top bin might or might not be ideal. I think this is a minor issue. //CHECK

**Examples:**

```reghazard
reghazard y //run without covariates
reghazard y grp //run with covariates grp
reghazard y, keepmax //include the max bin
reghazard y, keepmin //include the min bin, i.e., bin [0, lower)
```

### Extra Notes

- I wrote the hazard estimators in two functions, one generating the binned data and the other run the hazard regression. The advantage of having two functions is that users can incorporate their treatment variable (e.g., event study dummy for minimum wage bin) after running `bin_hazard`

- Not sure what would be the better names for the commands. 

- Do we need other functions? 
