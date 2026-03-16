#  Insurance Portfolio Analytics — End-to-End Data Project

> **Optimizing Underwriting, Loss Ratio Recovery & Retention Strategy**  
> Tools: `SQL` · `Power Query (M Language)` · `Excel` · `VBA` · `DAX`

---

##  Table of Contents

1. [Project Overview](#1-project-overview)
2. [Dataset & Schema](#2-dataset--schema)
3. [Phase 01 — Data Ingestion & Cleaning (Power Query + M Language)](#3-phase-01--data-ingestion--cleaning)
4. [Phase 02 — Feature Engineering (Calculated Columns)](#4-phase-02--feature-engineering)
5. [Phase 03 — Risk Scoring Model](#5-phase-03--risk-scoring-model)
6. [Phase 04 — SQL Analysis](#6-phase-04--sql-analysis)
7. [Phase 05 — Excel Report & VBA Automation](#7-phase-05--excel-report--vba-automation)
8. [Key Findings](#8-key-findings)
9. [Strategic Recommendations](#9-strategic-recommendations)

---

## 1. Project Overview

This project delivers a **full-stack insurance portfolio analysis** — from raw CSV ingestion through automated Excel reporting — across three analytical tracks:

| Track | Focus | Key Metric |
|-------|-------|------------|
|  Loss Ratio | Claims vs Premium profitability | LR = Claims ÷ Premiums |
|  Churn & Retention | Why customers leave | Churn Rate = Lapsed + Cancelled |
|  Pricing Segmentation | Risk-adjusted premium strategy | Risk Score = Age + Chronic + Claim |

**Portfolio size:** 5,000 policies · **Reference date:** 01 Jan 2025 · **Currency:** EGP

---

## 2. Dataset & Schema

### Raw Source (CSV — 9 columns)

```
Insurance_Claims_Dataset.csv
```

| Column | Type | Description |
|--------|------|-------------|
| `Policy_ID` | Text | Unique policy identifier |
| `Customer_Age` | Integer | Age at reference date (19–72) |
| `Gender` | Text | Male / Female |
| `Annual_Premium` | Integer | Annual premium in EGP |
| `Claim_Amount` | Integer | Total claims filed |
| `Policy_Type` | Text | Individual / Family / Corporate |
| `Chronic_Diseases` | Text | Yes / No / Unknown |
| `Last_Renewal_Date` | Date | Most recent renewal date |
| `Status` | Text | Active / Lapsed / Cancelled |

### Final Enriched Table (23 columns)

After cleaning and feature engineering, the dataset was extended with 14 derived columns across two phases.

---

## 3. Phase 01 — Data Ingestion & Cleaning

### Tool: Power Query (M Language)

Every transformation step was written in **M Language** inside the Advanced Editor. M follows a functional, step-chaining pattern:

```powerquery
let
    Step1 = <transform Step0>,
    Step2 = <transform Step1>,
    ...
in
    LastStep
```

### Cleaning Steps Applied

**Step 1 — Load CSV**
```powerquery
Source = Csv.Document(
    File.Contents("C:\...\Insurance_Claims_Dataset.csv"),
    [Delimiter=",", Columns=9, Encoding=65001]
)
```

**Step 2 — Promote Headers**
```powerquery
#"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true])
```
> Converts the first data row into column names.

**Step 3 — Set Column Types**
```powerquery
#"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{
    {"Policy_ID",        type text},
    {"Customer_Age",     Int64.Type},
    {"Gender",           type text},
    {"Annual_Premium",   Int64.Type},
    {"Claim_Amount",     Int64.Type},
    {"Policy_Type",      type text},
    {"Chronic_Diseases", type text},
    {"Last_Renewal_Date",type date},
    {"Status",           type text}
})
```
> Prevents silent type coercion errors in downstream calculations.

**Step 4 — Filter Null Rows**
```powerquery
#"Filtered Rows" = Table.SelectRows(#"Changed Type", each true)
```

**Step 5 — Trim Whitespace**
```powerquery
#"Trimmed Text" = Table.TransformColumns(#"Filtered Rows",{
    {"Policy_Type",      Text.Trim, type text},
    {"Chronic_Diseases", Text.Trim, type text}
})
```
> Removes leading/trailing spaces that break COUNTIF and SUMIF formulas.

**Step 6 — Handle Missing Values**
```powerquery
#"Replaced Value" = Table.ReplaceValue(
    #"Trimmed Text","","Unknown",
    Replacer.ReplaceValue,{"Gender"}
)
```
> Empty gender values → "Unknown" for consistent grouping.

---

## 4. Phase 02 — Feature Engineering

### Tool: Power Query (M Language continued)

#### 4.1 Outlier Flag — `Is_Outlier_Claim`

Identifies the **top 144 claims by value** using a dynamic threshold:

```powerquery
ClaimList = List.Sort(
    List.RemoveNulls(Table.Column(#"Replaced Value", "Claim_Amount")),
    Order.Descending
),
Threshold = ClaimList{143},  // 0-indexed: position 143 = 144th largest value

#"Added Flag" = Table.AddColumn(#"Replaced Value", "Is_Outlier_Claim",
    each [Claim_Amount] >= Threshold, type logical
)
```

> **Result:** 144 policies flagged TRUE — representing 2.9% of book.

#### 4.2 Age Band — `Age_Band`

```powerquery
#"Age Band" = Table.AddColumn(#"Added Flag", "Age_Band", each
    if [Customer_Age] < 30 then "Young"
    else if [Customer_Age] < 45 then "Middle"
    else if [Customer_Age] < 60 then "Senior"
    else "Elderly", type text
)
```

| Band | Age Range | Count |
|------|-----------|-------|
| Young | < 30 | 156 |
| Middle | 30–44 | 1,298 |
| Senior | 45–59 | 2,378 |
| Elderly | 60+ | 1,168 |

#### 4.3 Days Since Renewal — `Days_Since_Renewal`

```powerquery
#"Days Since Renewal" = Table.AddColumn(#"Age Band", "Days_Since_Renewal", each
    Duration.Days(DateTime.Date(DateTime.LocalNow()) - [Last_Renewal_Date]),
    Int64.Type
)
```

#### 4.4 Renewal Recency Bucket — `Renewal_Recency_Bucket`

```powerquery
#"Recency Bucket" = Table.AddColumn(#"Days Since Renewal", "Renewal_Recency_Bucket", each
    if [Days_Since_Renewal] <= 30  then "Very Recent"
    else if [Days_Since_Renewal] <= 90  then "Recent"
    else if [Days_Since_Renewal] <= 180 then "Moderate"
    else "Overdue", type text
)
```

>  **Data finding:** All 5,000 policies fall in the "Overdue" bucket (min days = 439). This means the entire portfolio was last renewed more than 6 months before the reference date.

#### 4.5 Claim Tier — `Claim_Tier`

```powerquery
#"Claim Tier" = Table.AddColumn(#"Recency Bucket", "Claim_Tier", each
    if [Claim_Amount] = 0      then "No Claim"
    else if [Claim_Amount] < 5000  then "Low"
    else if [Claim_Amount] < 20000 then "Medium"
    else "High", type text
)
```

#### 4.6 Churn Target — `Is_Churned`

```powerquery
#"Is Churned" = Table.AddColumn(#"Claim Tier", "Is_Churned", each
    if [Status] = "Lapsed" or [Status] = "Cancelled" then true else false,
    type logical
)
```

> Binary target variable for churn modeling.

#### 4.7 Date Parts — `Renewal_Year`, `Renewal_Month`, `Renewal_Quarter`

```powerquery
#"Date Parts"  = Table.AddColumn(#"Is Churned", "Renewal_Year",
    each Date.Year([Last_Renewal_Date]), Int64.Type),
#"Date Parts2" = Table.AddColumn(#"Date Parts", "Renewal_Month",
    each Date.Month([Last_Renewal_Date]), Int64.Type),
#"Date Parts3" = Table.AddColumn(#"Date Parts2", "Renewal_Quarter",
    each "Q" & Text.From(Date.QuarterOfYear([Last_Renewal_Date])), type text)
```

---

## 5. Phase 03 — Risk Scoring Model

### Tool: Power Query (M Language continued)

A **4-component additive risk model** producing scores from 4 to 14:

```
Total_Risk_Score = Age_Risk + Chronic_Risk + Claim_Risk + Policy_Risk
```

#### Component Weights

| Component | Condition | Score |
|-----------|-----------|-------|
| Age_Risk | < 30 years | 1 |
| | 30–44 years | 2 |
| | 45–59 years | 3 |
| | 60+ years | 4 |
| Chronic_Risk | No chronic disease | 1 |
| | Chronic = Yes | 3 |
| Claim_Risk | No claim | 1 |
| | Claim < 5,000 | 2 |
| | Claim < 20,000 | 3 |
| | Claim ≥ 20,000 | 4 |
| Policy_Risk | Individual | 1 |
| | Family | 2 |
| | Corporate | 3 |

#### M Language Implementation

```powerquery
#"Age Risk"     = Table.AddColumn(#"Date Parts3",  "Age_Risk",
    each if [Customer_Age] < 30 then 1
         else if [Customer_Age] < 45 then 2
         else if [Customer_Age] < 60 then 3
         else 4, Int64.Type),

#"Chronic Risk" = Table.AddColumn(#"Age Risk",     "Chronic_Risk",
    each if [Chronic_Diseases] = "Yes" then 3 else 1, Int64.Type),

#"Claim Risk"   = Table.AddColumn(#"Chronic Risk", "Claim_Risk",
    each if [Claim_Amount] = 0      then 1
         else if [Claim_Amount] < 5000  then 2
         else if [Claim_Amount] < 20000 then 3
         else 4, Int64.Type),

#"Policy Risk"  = Table.AddColumn(#"Claim Risk",   "Policy_Risk",
    each if [Policy_Type] = "Individual" then 1
         else if [Policy_Type] = "Family" then 2
         else 3, Int64.Type),

#"Total Risk Score" = Table.AddColumn(#"Policy Risk", "Total_Risk_Score",
    each [Age_Risk] + [Chronic_Risk] + [Claim_Risk] + [Policy_Risk], Int64.Type),

#"Risk Tier"    = Table.AddColumn(#"Total Risk Score", "Risk_Tier",
    each if [Total_Risk_Score] <= 5  then "Low Risk"
         else if [Total_Risk_Score] <= 8  then "Medium Risk"
         else if [Total_Risk_Score] <= 11 then "High Risk"
         else "Critical Risk", type text)
```

#### Risk Distribution Results

| Tier | Score Range | Count | % Portfolio |
|------|-------------|-------|-------------|
| Low Risk | 4–5 | 467 | 9.3% |
| Medium Risk | 6–8 | 2,923 | 58.5% |
| High Risk | 9–11 | 1,490 | 29.8% |
| Critical Risk | 12–14 | 120 | 2.4% |

---

## 6. Phase 04 — SQL Analysis

The same dataset was analyzed in SQL to validate Excel findings and compute segment-level KPIs.

### Loss Ratio by Policy Type

```sql
SELECT
    Policy_Type,
    SUM(Annual_Premium)                              AS Total_Premium,
    SUM(Claim_Amount)                                AS Total_Claims,
    ROUND(SUM(Claim_Amount) * 1.0 / SUM(Annual_Premium), 4) AS Loss_Ratio
FROM Insurance_Claims
GROUP BY Policy_Type
ORDER BY Loss_Ratio DESC;
```

| Policy Type | Total Premium | Total Claims | Loss Ratio |
|-------------|--------------|-------------|------------|
| Individual | 28,793,565 | 27,587,869 | **95.8%**  |
| Family | 22,636,849 | 9,322,299 | 41.2%  |
| Corporate | 16,945,706 | 2,932,576 | **17.3%**  |

### Outlier Impact Analysis

```sql
-- With outliers
SELECT SUM(Claim_Amount), ROUND(SUM(Claim_Amount)*1.0/SUM(Annual_Premium),4)
FROM Insurance_Claims;
-- Result: 39,842,744 | LR: 58.3%

-- Without outliers (Claims > 60,000 removed)
SELECT SUM(Claim_Amount), ROUND(SUM(Claim_Amount)*1.0/SUM(Annual_Premium),4)
FROM Insurance_Claims
WHERE Claim_Amount <= 60000;
-- Result: 17,498,088 | LR: 25.6%
```

> **144 policies → 22.3M EGP → removed LR drops from 58% to 26%**

### Churn Rate by Risk Tier

```sql
SELECT
    Risk_Tier,
    COUNT(*) AS Total,
    SUM(CASE WHEN Status IN ('Lapsed','Cancelled') THEN 1 ELSE 0 END) AS Churned,
    ROUND(SUM(CASE WHEN Status IN ('Lapsed','Cancelled') THEN 1.0 ELSE 0 END) / COUNT(*), 4) AS Churn_Rate
FROM Insurance_Claims
GROUP BY Risk_Tier
ORDER BY Churn_Rate DESC;
```

### Pricing Gap Analysis

```sql
SELECT
    Risk_Tier,
    ROUND(AVG(Annual_Premium), 0) AS Avg_Premium,
    ROUND(AVG(Claim_Amount), 0)   AS Avg_Claim,
    ROUND(SUM(Claim_Amount)*1.0/SUM(Annual_Premium), 4) AS Loss_Ratio
FROM Insurance_Claims
GROUP BY Risk_Tier;
```

| Tier | Avg Premium | Avg Claim | LR |
|------|------------|----------|----|
| Low Risk | 13,612 | 1,144 | 8.4% |
| Medium Risk | 13,716 | 6,608 | 48.2% |
| High Risk | **13,726** | **23,542** | **171.5%** |

> **Critical finding:** EGP 114 premium difference between Low and High Risk, despite a 22,000 EGP gap in average claims.

---

## 7. Phase 05 — Excel Report & VBA Automation

### Report Structure

The Excel workbook contains 5 sheets:

| Sheet | Color | Content |
|-------|-------|---------|
| `Insurance_Claims` | Navy | Raw data + all 23 enriched columns |
| `Executive_Summary` | Navy | KPI tiles + findings table |
| `Loss Ratio Analysis` | Teal | 5 analytical tables + outlier impact |
| `Churn Retention` | Red | KPI dashboard + 5 churn tables |
| `Pricing Segmentation` | Green | Risk methodology + heat map |

### Excel Formulas Used

**Dynamic KPI calculations (cross-sheet references):**

```excel
-- Total Claims
=SUM(Insurance_Claims[Claim_Amount])

-- Portfolio Loss Ratio
=SUM(Insurance_Claims[Claim_Amount])/SUM(Insurance_Claims[Annual_Premium])

-- Churn Rate
=(COUNTIF(Insurance_Claims[Status],"Lapsed")
 +COUNTIF(Insurance_Claims[Status],"Cancelled"))
 /COUNTA(Insurance_Claims[Policy_ID])

-- Corporate Loss Ratio
=SUMIF(Insurance_Claims!F5:F5004,"Corporate",Insurance_Claims!P5:P5004)
/SUMIF(Insurance_Claims!F5:F5004,"Corporate",Insurance_Claims!O5:O5004)

-- Outlier Claims Count
=COUNTIF(Insurance_Claims[Is_Outlier_Claim],TRUE)

-- Loss Ratio Heat Map (Age × Chronic)
=SUMIFS(Claims,AgeBand,"Young",Chronic,"Yes")
/SUMIFS(Premium,AgeBand,"Young",Chronic,"Yes")
```

### VBA Automation

A single master macro formats all 4 analytical sheets in one click.

**Architecture:**

```vba
' Color constants (defined once, used everywhere)
Const NAVY      As Long = 1779786   ' RGB(27,42,74)
Const TEAL      As Long = 7684365   ' RGB(13,115,119)
Const RED_DARK  As Long = 2826432   ' RGB(192,57,43)
Const GREEN     As Long = 4789569   ' RGB(30,132,73)

' Helper subs (reusable across all sheets)
Sub StyleHeader(ws, r, c1, c2, bg)      ' Section headers
Sub StyleTableHeader(ws, r, c1, c2)     ' Table column headers

' Sheet-specific formatters
Sub FormatExecutiveSummary()
Sub FormatLossRatio()
Sub FormatChurnRetention()
Sub FormatPricingSegmentation()

' Master entry point
Sub FormatFullReport()
    Call FormatExecutiveSummary
    Call FormatLossRatio
    Call FormatChurnRetention
    Call FormatPricingSegmentation
End Sub
```

**Conditional color logic for Loss Ratio cells:**

```vba
If val >= 0.9 Then
    cell.Interior.Color = RED_LIGHT   ' Critical — near breakeven
    cell.Font.Color     = RED_DARK
ElseIf val >= 0.7 Then
    cell.Interior.Color = YLW_LIGHT   ' Moderate — monitor
    cell.Font.Color     = RGB(243, 156, 18)
Else
    cell.Interior.Color = GRN_LIGHT   ' Healthy — scale up
    cell.Font.Color     = GREEN
End If
```

---

## 8. Key Findings

###  Loss Ratio

| Finding | Value | Severity |
|---------|-------|----------|
| Individual policy LR | 95.8% |  CRITICAL |
| Corporate policy LR | 17.3% |  PROFITABLE |
| Outlier claims (144 policies) | 1,238% LR |  CRITICAL |
| Removing 144 outliers drops LR | 58% → 26% |  High concentration risk |
| Young customers (<30) LR | 72% |  HIGH — underpriced |
| Individual + Unknown Chronic LR | 104% |  Loss-making |

###  Churn & Retention

| Finding | Value | Severity |
|---------|-------|----------|
| Overall churn rate | 49.5% |  CRITICAL (target: <20%) |
| Churn at < 600 days | 20.1% |  
| Churn at > 900 days | 55.6% |  CRITICAL |
| Churned customers avg claim | 10,000 EGP | vs 5,980 retained |
| 60+ Chronic customers churn | 51.5% |  HIGH |

###  Pricing Segmentation

| Finding | Value | Severity |
|---------|-------|----------|
| High Risk LR | 171.5% |  CRITICAL |
| Premium gap Low vs High Risk | EGP 114 |  HIGH — effectively no differentiation |
| High Risk % of portfolio | 29.8% |  Large exposure |

---

## 9. Strategic Recommendations

###  Immediate Actions (This Quarter)

**1. Reprice Individual + High Risk Segment**
- Apply minimum **+35% premium loading** on High Risk renewals
- Apply minimum **+75% loading** on Critical Risk (12–14 score)
- Gate renewals for policies with LR > 200%

**2. Stop-Loss Reinsurance**
- Implement reinsurance cap at **50,000 EGP per claim**
- Mandate clinical pre-authorization for claims > 30,000 EGP
- Flag Chronic + Age > 60 for automatic pre-auth review

**3. Retention Campaign — 600-Day Trigger**
- Launch outreach at **550 days** post-renewal (50 days before the churn inflection point)
- Offer loyalty discount of 5–8% for customers renewing before day 600
- Outbound call + 30-day grace period for customers past day 900

###  Next Cycle (Next 6 Months)

**4. Correct Young Adult Pricing**
- 72% LR for customers under 30 signals significant underpricing
- Apply **+25% loading** for age 18–29 group at next renewal

**5. Mandatory Medical Disclosure**
- 10.3% of policies have "Unknown" chronic status — these show 65% LR vs 56% for confirmed non-chronic
- Enforce disclosure at point of sale to eliminate latent risk

**6. Corporate Acquisition Push**
- Corporate at 17.3% LR is the most profitable segment by far
- Increase B2B marketing and SME group policy incentives

###  Maintain (Ongoing)

**7. Protect Low-Risk Customers**
- Low Risk customers are paying EGP 13,612 avg premium for only 8.4% LR
- They are effectively subsidizing High Risk losses — a classic "death spiral" setup
- Offer renewal discounts or loyalty bonuses to retain this segment before they reprice elsewhere

**8. Corporate Retention**
- 52.5% churn in Corporate is surprisingly high
- Implement quarterly health-benefit review meetings for all corporate accounts
- Target: maintain and improve 47.5% corporate retention rate

---

##  Tech Stack

```
Data Source      →  CSV (9 columns, 5,000 rows)
Ingestion        →  Power Query (M Language)
Cleaning         →  Power Query — 6 transformation steps
Feature Eng.     →  Power Query — 14 derived columns
Risk Scoring     →  Power Query — 4-component additive model
SQL Analysis     →  SQL — validation + segment KPIs
Excel Report     →  5-sheet workbook with dynamic SUMIF/COUNTIFS
Automation       →  VBA — 1 master macro, 4 sheet formatters
```

---

##  File Structure

```
 Insurance-Portfolio-Analytics
 ┣  Insurance_Analysis.xlsm        ← Main workbook (macro-enabled)
 ┣  Insurance_Claims_Dataset.csv   ← Raw source data
 ┣  Insurance_VBA_ColorCodes.bas   ← VBA module (importable)
 ┗  README.md                      ← This file
```

---

*Analysis reference date: 01 January 2025 · Portfolio: 5,000 policies · Currency: EGP*
