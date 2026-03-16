/* ============================================================
   INSURANCE CLAIMS — FULL ANALYTICAL SUITE
   Database : SQL Server 2016+ (T-SQL)
   Dataset  : Insurance_Claims_Raw  (5,000 rows)
   Sections :
     01  Data Quality Audit
     02  Loss Ratio Analysis
     03  Customer Churn & Retention
     04  Customer Segmentation for Pricing
     05  Executive KPI Summary View
   ============================================================ */

/*  SECTION 01 — DATA QUALITY AUDIT  */

-- 01.A  Row count & quick shape
SELECT
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT Policy_ID) AS Unique_Policies,
    COUNT(DISTINCT Policy_Type) AS Policy_Types,
    COUNT(DISTINCT Status) AS Status_Values,
    MIN(Last_Renewal_Date) AS Earliest_Renewal,
    MAX(Last_Renewal_Date) AS Latest_Renewal,
    DATEDIFF(DAY, MIN(Last_Renewal_Date),
                  MAX(Last_Renewal_Date)) AS Date_Span_Days
FROM dbo.Insurance_Claims;
GO

-- 01.B  NULL audit — every column
SELECT
    SUM(CASE WHEN Policy_ID  IS NULL THEN 1 ELSE 0 END) AS NULL_Policy_ID,
    SUM(CASE WHEN Customer_Age  IS NULL THEN 1 ELSE 0 END) AS NULL_Age,
    SUM(CASE WHEN Gender  IS NULL THEN 1 ELSE 0 END) AS NULL_Gender,
    SUM(CASE WHEN Annual_Premium IS NULL THEN 1 ELSE 0 END) AS NULL_Premium,
    SUM(CASE WHEN Claim_Amount IS NULL THEN 1 ELSE 0 END) AS NULL_Claim,
    SUM(CASE WHEN Policy_Type IS NULL THEN 1 ELSE 0 END) AS NULL_PolicyType,
    SUM(CASE WHEN Chronic_Diseases  IS NULL THEN 1 ELSE 0 END) AS NULL_Chronic,
    SUM(CASE WHEN Last_Renewal_Date IS NULL THEN 1 ELSE 0 END) AS NULL_RenewalDate,
    SUM(CASE WHEN Status  IS NULL THEN 1 ELSE 0 END) AS NULL_Status
FROM dbo.Insurance_Claims;
GO

-- 01.C  Claim_Amount distribution flags
SELECT
    COUNT(*) AS Total_Policies,
    SUM(CASE WHEN Claim_Amount = 0 THEN 1 ELSE 0 END) AS Zero_Claim_Count,
    CAST(SUM(CASE WHEN Claim_Amount = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) AS Zero_Claim_Pct,
    SUM(CASE WHEN Claim_Amount > 0
             AND Claim_Amount <= 8000 THEN 1 ELSE 0 END) AS Small_Claims,
    SUM(CASE WHEN Claim_Amount > 8000
             AND Claim_Amount <= 60000 THEN 1 ELSE 0 END) AS Medium_Claims,
    SUM(CASE WHEN Claim_Amount > 60000 THEN 1 ELSE 0 END) AS Outlier_Claims,
    MAX(Claim_Amount) AS Max_Claim,
    MIN(CASE WHEN Claim_Amount > 0
             THEN Claim_Amount END) AS Min_NonZero_Claim,
    AVG(CAST(Claim_Amount AS BIGINT)) AS Avg_Claim_AllRows,
    AVG(CASE WHEN Claim_Amount > 0
             THEN CAST(Claim_Amount AS BIGINT) END) AS Avg_Claim_Claimants_Only
FROM dbo.Insurance_Claims;
GO

-- 01.D  Categorical value frequencies
SELECT 'Gender' AS Column_Name, CAST(Gender AS nvarchar(max)) AS Value,COUNT(*) AS Freq 
FROM dbo.Insurance_Claims 
GROUP BY Gender
UNION ALL
SELECT 'Policy_Type', CAST(Policy_Type AS nvarchar(max)),COUNT(*) 
FROM dbo.Insurance_Claims 
GROUP BY Policy_Type
UNION ALL
SELECT 'Chronic_Diseases', CAST(Chronic_Diseases AS nvarchar(max)),COUNT(*) 
FROM dbo.Insurance_Claims 
GROUP BY Chronic_Diseases
UNION ALL
SELECT 'Status', CAST(Status AS nvarchar(max)),COUNT(*) 
FROM dbo.Insurance_Claims 
GROUP BY Status
ORDER BY Column_Name, Freq DESC;
GO

/*   SECTION 02 — LOSS RATIO ANALYSIS
     Loss Ratio = Total Claims Paid / Total Premiums Collected
     Healthy target: < 60–70% for insurance portfolios           */
 

-- 02.A  Overall portfolio Loss Ratio
SELECT
    SUM(Annual_Premium) AS Total_Premium_EGP,
    SUM(Claim_Amount) AS Total_Claims_EGP,
    CAST(SUM(Claim_Amount) * 100.0 / NULLIF(SUM(Annual_Premium), 0) AS DECIMAL(6,2)) AS Loss_Ratio_Pct,
    CAST(SUM(Claim_Amount) * 1.0 / NULLIF(COUNT(*), 0) AS DECIMAL(10,2)) AS Avg_Claim_Per_Policy,
    CAST(SUM(Annual_Premium) * 1.0 / NULLIF(COUNT(*), 0) AS DECIMAL(10,2)) AS Avg_Premium_Per_Policy
FROM dbo.Insurance_Claims;
GO

-- 02.B  Loss Ratio by Policy_Type  ← PRICING LEVER
SELECT
    Policy_Type,
    COUNT(*) AS Policy_Count,
    SUM(Annual_Premium) AS Total_Premium,
    SUM(Claim_Amount) AS Total_Claims,
    CAST(SUM(Claim_Amount) * 100.0 / NULLIF(SUM(Annual_Premium), 0) AS DECIMAL(6,2)) AS Loss_Ratio_Pct,
    AVG(CAST(Annual_Premium AS BIGINT)) AS Avg_Premium,
    AVG(CASE WHEN Claim_Amount > 0 THEN CAST(Claim_Amount AS BIGINT) END) AS Avg_Claim_Claimants,
    SUM(CASE WHEN Claim_Amount > 0 THEN 1 ELSE 0 END)  AS Claimant_Count,
    CAST(SUM(CASE WHEN Claim_Amount > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) AS Claim_Frequency_Pct
FROM dbo.Insurance_Claims
GROUP BY Policy_Type
ORDER BY Loss_Ratio_Pct DESC;
GO

-- 02.C  Loss Ratio by Chronic_Diseases  ← UNDERWRITING SIGNAL
SELECT
    Chronic_Diseases,
    COUNT(*) AS Policy_Count,
    SUM(Annual_Premium) AS Total_Premium,
    SUM(Claim_Amount)  AS Total_Claims,
    CAST(SUM(Claim_Amount) * 100.0 / NULLIF(SUM(Annual_Premium), 0) AS DECIMAL(6,2)) AS Loss_Ratio_Pct,
    CAST(AVG(CAST(Annual_Premium AS FLOAT)) AS DECIMAL(10,2)) AS Avg_Premium,
    CAST(SUM(CASE WHEN Claim_Amount > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) AS Claim_Frequency_Pct
FROM dbo.Insurance_Claims
GROUP BY Chronic_Diseases
ORDER BY Loss_Ratio_Pct DESC;
GO

-- 02.D  Loss Ratio by Age Bucket  ← AGE-BAND PRICING
SELECT
    CASE
        WHEN Customer_Age BETWEEN 18 AND 29 THEN '18–29'
        WHEN Customer_Age BETWEEN 30 AND 39 THEN '30–39'
        WHEN Customer_Age BETWEEN 40 AND 49 THEN '40–49'
        WHEN Customer_Age BETWEEN 50 AND 59 THEN '50–59'
        ELSE '60–75'
    END  AS Age_Band,
    COUNT(*) AS Policy_Count,
    AVG(CAST(Annual_Premium AS FLOAT)) AS Avg_Premium,
    SUM(Claim_Amount) AS Total_Claims,
    CAST(SUM(Claim_Amount) * 100.0 / NULLIF(SUM(Annual_Premium), 0) AS DECIMAL(6,2)) AS Loss_Ratio_Pct,
    CAST(SUM(CASE WHEN Claim_Amount > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) AS Claim_Frequency_Pct
FROM dbo.Insurance_Claims
GROUP BY
    CASE
        WHEN Customer_Age BETWEEN 18 AND 29 THEN '18–29'
        WHEN Customer_Age BETWEEN 30 AND 39 THEN '30–39'
        WHEN Customer_Age BETWEEN 40 AND 49 THEN '40–49'
        WHEN Customer_Age BETWEEN 50 AND 59 THEN '50–59'
        ELSE '60–75'
    END
ORDER BY Age_Band;
GO

-- 02.E  Cross-tab: Policy_Type × Chronic_Diseases (Loss Ratio matrix)
SELECT
    Policy_Type,
    ROUND(AVG(CASE WHEN Chronic_Diseases = 1 
                   THEN Claim_Amount * 100.0 / NULLIF(Annual_Premium, 0) END),2) AS LR_Chronic_Yes,
    ROUND(AVG(CASE WHEN Chronic_Diseases = 0 
                   THEN Claim_Amount * 100.0 / NULLIF(Annual_Premium, 0) END),2) AS LR_Chronic_No,
    ROUND(AVG(CASE WHEN Chronic_Diseases IS NULL 
                   THEN Claim_Amount * 100.0 / NULLIF(Annual_Premium, 0) END),2) AS LR_Chronic_Unknown,
    ROUND(AVG(Claim_Amount * 100.0 / NULLIF(Annual_Premium, 0)), 2) AS LR_Overall
FROM dbo.Insurance_Claims
GROUP BY Policy_Type
ORDER BY Policy_Type;
GO

-- 02.F  Top 20 outlier claims (Pareto check)
-- Goal: see if 20% of claims drive 80% of total losses
SELECT TOP 20
    Policy_ID,
    Customer_Age,
    Gender,
    Policy_Type,
    Chronic_Diseases,
    Annual_Premium,
    Claim_Amount,
    CAST(Claim_Amount * 100.0 / NULLIF(Annual_Premium, 0) AS DECIMAL(8,1)) AS Individual_Loss_Ratio_Pct,
    Status
FROM dbo.Insurance_Claims
WHERE Claim_Amount > 0
ORDER BY Claim_Amount DESC;
GO

-- 02.G  Cumulative loss concentration (Pareto / 80-20 rule)
WITH Ranked AS (
    SELECT
        Claim_Amount,
        ROW_NUMBER() OVER (ORDER BY Claim_Amount DESC) AS Rn,
        COUNT(*) OVER () AS Total_Count,
        SUM(Claim_Amount) OVER () AS Grand_Total
    FROM dbo.Insurance_Claims
    WHERE Claim_Amount > 0
),
Cumulative AS (
    SELECT
        Rn,
        Claim_Amount,
        Total_Count,
        Grand_Total,
        SUM(Claim_Amount) OVER (ORDER BY Rn ROWS UNBOUNDED PRECEDING) AS Cumul_Claims
    FROM Ranked
)
SELECT
    Rn  AS Rank,
    Claim_Amount,
    CAST(Rn * 100.0 / Total_Count AS DECIMAL(5,1)) AS Top_Pct_Of_Claimants,
    CAST(Cumul_Claims * 100.0 / Grand_Total AS DECIMAL(5,1)) AS Cumul_Loss_Pct
FROM Cumulative
WHERE Rn IN (1,5,10,20,50,100,200,500)   
ORDER BY Rn;
GO

-- 02.H  Year-over-Year Loss Ratio trend
SELECT
    YEAR(Last_Renewal_Date) AS Renewal_Year,
    COUNT(*) AS Policies,
    SUM(Annual_Premium) AS Total_Premium,
    SUM(Claim_Amount) AS Total_Claims,
    CAST(SUM(Claim_Amount) * 100.0
         / NULLIF(SUM(Annual_Premium), 0)
         AS DECIMAL(6,2)) AS Loss_Ratio_Pct
FROM dbo.Insurance_Claims
GROUP BY YEAR(Last_Renewal_Date)
ORDER BY Renewal_Year;
GO


/*  SECTION 03 — CUSTOMER CHURN & RETENTION ANALYSIS
    Churned = Status IN ('Lapsed', 'Cancelled')
    Retained = Status = 'Active'  */

-- 03.A  Overall churn rate
SELECT
    COUNT(*) AS Total_Customers,
    SUM(CASE WHEN Status = 'Active' THEN 1 ELSE 0 END) AS Active,
    SUM(CASE WHEN Status = 'Lapsed' THEN 1 ELSE 0 END) AS Lapsed,
    SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END) AS Cancelled,
    SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
             THEN 1 ELSE 0 END) AS Total_Churned,
    CAST(SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
                  THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,1)) AS Churn_Rate_Pct,
    CAST(SUM(CASE WHEN Status = 'Active'
                  THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,1)) AS Retention_Rate_Pct
FROM dbo.Insurance_Claims;
GO

-- 03.B  Churn rate by Policy_Type
SELECT
    Policy_Type,
    COUNT(*) AS Total,
    SUM(CASE WHEN Status = 'Active' THEN 1 ELSE 0 END) AS Active,
    SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
             THEN 1 ELSE 0 END) AS Churned,
    CAST(SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
                  THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,1)) AS Churn_Rate_Pct
FROM dbo.Insurance_Claims
GROUP BY Policy_Type
ORDER BY Churn_Rate_Pct DESC;
GO

-- 03.C  Churn rate by Age Band
SELECT
    CASE
        WHEN Customer_Age BETWEEN 18 AND 29 THEN '18–29'
        WHEN Customer_Age BETWEEN 30 AND 39 THEN '30–39'
        WHEN Customer_Age BETWEEN 40 AND 49 THEN '40–49'
        WHEN Customer_Age BETWEEN 50 AND 59 THEN '50–59'
        ELSE '60–75'
    END AS Age_Band,
    COUNT(*) AS Total,
    SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
             THEN 1 ELSE 0 END) AS Churned,
    CAST(SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
                  THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,1)) AS Churn_Rate_Pct,
    AVG(CAST(Annual_Premium AS FLOAT)) AS Avg_Premium,
    AVG(CAST(Claim_Amount AS FLOAT))AS Avg_Claim
FROM dbo.Insurance_Claims
GROUP BY
    CASE
        WHEN Customer_Age BETWEEN 18 AND 29 THEN '18–29'
        WHEN Customer_Age BETWEEN 30 AND 39 THEN '30–39'
        WHEN Customer_Age BETWEEN 40 AND 49 THEN '40–49'
        WHEN Customer_Age BETWEEN 50 AND 59 THEN '50–59'
        ELSE '60–75'
    END
ORDER BY Age_Band;
GO

-- 03.D  Days_Since_Renewal — the most powerful churn predictor
-- The more days since last renewal, the higher the churn risk
SELECT
    CASE
        WHEN DATEDIFF(DAY, Last_Renewal_Date, GETDATE()) <=  180 THEN '0–6 Months'
        WHEN DATEDIFF(DAY, Last_Renewal_Date, GETDATE()) <=  365 THEN '6–12 Months'
        WHEN DATEDIFF(DAY, Last_Renewal_Date, GETDATE()) <=  730 THEN '1–2 Years'
        ELSE '2+ Years'
    END AS Recency_Bucket,
    COUNT(*) AS Total,
    SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
             THEN 1 ELSE 0 END) AS Churned,
    CAST(SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
                  THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,1)) AS Churn_Rate_Pct
FROM dbo.Insurance_Claims
GROUP BY
    CASE
        WHEN DATEDIFF(DAY, Last_Renewal_Date, GETDATE()) <=  180 THEN '0–6 Months'
        WHEN DATEDIFF(DAY, Last_Renewal_Date, GETDATE()) <=  365 THEN '6–12 Months'
        WHEN DATEDIFF(DAY, Last_Renewal_Date, GETDATE()) <=  730 THEN '1–2 Years'
        ELSE '2+ Years'
    END
ORDER BY Churn_Rate_Pct DESC;
GO

-- 03.E  Churn rate by Claim behavior
-- Insight: do customers who filed claims churn more or less?
SELECT
    CASE
        WHEN Claim_Amount = 0 THEN 'No Claim'
        WHEN Claim_Amount BETWEEN 1 AND 8000  THEN 'Small Claim (1–8k)'
        WHEN Claim_Amount BETWEEN 8001 AND 60000 THEN 'Medium Claim (8k–60k)'
        ELSE 'Large Claim (>60k)'
    END AS Claim_Tier,
    COUNT(*) AS Total,
    SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
             THEN 1 ELSE 0 END) AS Churned,
    CAST(SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
                  THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,1)) AS Churn_Rate_Pct,
    AVG(CAST(Annual_Premium AS FLOAT)) AS Avg_Premium
FROM dbo.Insurance_Claims
GROUP BY
    CASE
        WHEN Claim_Amount = 0 THEN 'No Claim'
        WHEN Claim_Amount BETWEEN 1 AND 8000 THEN 'Small Claim (1–8k)'
        WHEN Claim_Amount BETWEEN 8001 AND 60000 THEN 'Medium Claim (8k–60k)'
        ELSE 'Large Claim (>60k)'
    END
ORDER BY Churn_Rate_Pct DESC;
GO

-- 03.F  Chronic Disease × Status interaction
SELECT
    Chronic_Diseases,
    Status,
    COUNT(*) AS Count,
    CAST(COUNT(*) * 100.0
         / SUM(COUNT(*)) OVER (PARTITION BY Chronic_Diseases)
         AS DECIMAL(5,1)) AS Pct_Within_Chronic_Group
FROM dbo.Insurance_Claims
GROUP BY Chronic_Diseases, Status
ORDER BY Chronic_Diseases, Status;
GO

-- 03.G  Lapsed policies at risk of full cancellation
-- (Already Lapsed AND renewal date is old = immediate intervention needed)
SELECT
    Policy_ID,
    Customer_Age,
    Gender,
    Policy_Type,
    Annual_Premium,
    Claim_Amount,
    Last_Renewal_Date,
    DATEDIFF(DAY, Last_Renewal_Date, GETDATE())AS Days_Since_Renewal,
    Chronic_Diseases
FROM dbo.Insurance_Claims
WHERE Status = 'Lapsed'
  AND DATEDIFF(DAY, Last_Renewal_Date, GETDATE()) > 365
ORDER BY Days_Since_Renewal DESC;
GO

-- 03.H  Revenue at risk from churned customers
SELECT
    Status,
    COUNT(*) AS Policies,
    SUM(Annual_Premium) AS Premium_At_Risk_EGP,
    CAST(SUM(Annual_Premium) * 100.0 / (SELECT SUM(Annual_Premium) FROM dbo.Insurance_Claims) AS DECIMAL(5,1)) AS Pct_Of_Total_Premium
FROM dbo.Insurance_Claims
WHERE Status IN ('Lapsed', 'Cancelled')
GROUP BY Status
UNION ALL
SELECT
    'TOTAL CHURNED',
    COUNT(*),
    SUM(Annual_Premium),
    CAST(SUM(Annual_Premium) * 100.0 / (SELECT SUM(Annual_Premium) FROM dbo.Insurance_Claims) AS DECIMAL(5,1))
FROM dbo.Insurance_Claims
WHERE Status IN ('Lapsed', 'Cancelled');
GO


/*    SECTION 04 — CUSTOMER SEGMENTATION FOR PRICING
      We build a Risk Score (0–100) using:
      • Age-band risk weight
      • Chronic disease flag
      • Claim history
      • Policy type
   Then assign Risk Tier: Low / Medium / High / Very High  */

-- 04.A  Build the segmentation CTE with Risk Score
WITH RiskScore AS (
    SELECT
        Policy_ID,
        Customer_Age,
        Gender,
        Annual_Premium,
        Claim_Amount,
        Policy_Type,
        Chronic_Diseases,
        Last_Renewal_Date,
        Status,
        CASE
            WHEN Customer_Age BETWEEN 18 AND 29 THEN  5
            WHEN Customer_Age BETWEEN 30 AND 39 THEN  8
            WHEN Customer_Age BETWEEN 40 AND 49 THEN 12
            WHEN Customer_Age BETWEEN 50 AND 59 THEN 18
            ELSE 22
        END  AS Age_Score,     

        -- Fixed bit comparison logic here
        CASE 
            WHEN Chronic_Diseases = 1 THEN 25       -- 1 is 'Yes'
            WHEN Chronic_Diseases IS NULL THEN 12   -- NULL is 'Unknown'
            ELSE 0                                  -- 0 is 'No'
        END AS Chronic_Score,  

        CASE
            WHEN Claim_Amount = 0  THEN  0
            WHEN Claim_Amount <=  8000  THEN  8
            WHEN Claim_Amount <= 40000  THEN 18
            ELSE 30
        END AS Claim_Score, 

        CASE Policy_Type
            WHEN 'Corporate'  THEN 10
            WHEN 'Family'     THEN 15
            ELSE 5
        END  AS PolicyType_Score 
    FROM dbo.Insurance_Claims
),
Scored AS (
    SELECT *,
        (Age_Score + Chronic_Score + Claim_Score + PolicyType_Score) AS Total_Risk_Score,
        CASE
            WHEN (Age_Score + Chronic_Score + Claim_Score + PolicyType_Score) <= 20 THEN 'Low Risk'
            WHEN (Age_Score + Chronic_Score + Claim_Score + PolicyType_Score) <= 40 THEN 'Medium Risk'
            WHEN (Age_Score + Chronic_Score + Claim_Score + PolicyType_Score) <= 60 THEN 'High Risk'
            ELSE 'Very High Risk'
        END AS Risk_Tier
    FROM RiskScore
)
SELECT *
INTO CustomerSegments
FROM Scored;
GO

-- 04.C  Suggested premium adjustment by segment
SELECT
    Risk_Tier,
    CAST(AVG(CAST(Annual_Premium AS FLOAT)) AS DECIMAL(10,0)) AS Current_Avg_Premium,
    CAST(SUM(Claim_Amount) * 100.0 / NULLIF(SUM(Annual_Premium),0) AS DECIMAL(6,2)) AS Loss_Ratio_Pct,
    -- A simple re-pricing formula: if LR > 65%, increase premium proportionally
    CAST( AVG(CAST(Annual_Premium AS FLOAT)) * (SUM(CAST(Claim_Amount AS FLOAT)) / NULLIF(SUM(CAST(Annual_Premium AS FLOAT)), 0))
        / 0.65      -- target Loss Ratio of 65%
        AS DECIMAL(10,0)) AS Suggested_Premium_EGP,
    CAST((AVG(CAST(Annual_Premium AS FLOAT)) * (SUM(CAST(Claim_Amount AS FLOAT)) / NULLIF(SUM(CAST(Annual_Premium AS FLOAT)), 0))
            / 0.65) - AVG(CAST(Annual_Premium AS FLOAT))
        AS DECIMAL(10,0)) AS Premium_Adjustment_EGP

FROM CustomerSegments
GROUP BY Risk_Tier
ORDER BY
    CASE Risk_Tier
        WHEN 'Low Risk' THEN 1
        WHEN 'Medium Risk' THEN 2
        WHEN 'High Risk'  THEN 3
        WHEN 'Very High Risk' THEN 4
    END;
GO

-- 04.E  Segment × Chronic Disease interaction
SELECT
    Risk_Tier,
    Chronic_Diseases,
    COUNT(*) AS Count,
    AVG(CAST(Annual_Premium AS FLOAT)) AS Avg_Premium,
    AVG(CAST(Claim_Amount AS FLOAT)) AS Avg_Claim,
    CAST(SUM(Claim_Amount) * 100.0 / NULLIF(SUM(Annual_Premium),0) AS DECIMAL(6,2)) AS Loss_Ratio_Pct
FROM CustomerSegments
GROUP BY Risk_Tier, Chronic_Diseases
ORDER BY
    CASE Risk_Tier
        WHEN 'Low Risk' THEN 1
        WHEN 'Medium Risk' THEN 2
        WHEN 'High Risk' THEN 3
        WHEN 'Very High Risk' THEN 4
    END, Chronic_Diseases;
GO

-- 04.F  Full customer profile with segment tag (use for reporting)
SELECT
    Policy_ID,
    Customer_Age,
    ISNULL(Gender, 'Unknown') AS Gender,
    Policy_Type,
    Annual_Premium,
    Claim_Amount,
    Chronic_Diseases,
    Last_Renewal_Date,
    DATEDIFF(DAY, Last_Renewal_Date, GETDATE()) AS Days_Since_Renewal,
    Status,
    Total_Risk_Score,
    Risk_Tier,
    -- Renewal urgency flag
    CASE
        WHEN Status = 'Lapsed'
             AND DATEDIFF(DAY, Last_Renewal_Date, GETDATE()) > 180
        THEN 'URGENT: Re-engage'
        WHEN Status = 'Active'
             AND DATEDIFF(DAY, Last_Renewal_Date, GETDATE()) > 300
        THEN 'Renewal Due Soon'
        ELSE 'OK'
    END   AS Action_Flag
FROM CustomerSegments
ORDER BY Total_Risk_Score DESC, Claim_Amount DESC;
GO


/*  SECTION 05 — EXECUTIVE KPI SUMMARY VIEW
    Create a reusable view for dashboards / reports   */

IF OBJECT_ID('dbo.vw_Insurance_KPIs', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Insurance_KPIs;
GO

CREATE VIEW dbo.vw_Insurance_KPIs AS
SELECT
    -- Portfolio scale
    COUNT(*) AS Total_Policies,
    SUM(Annual_Premium) AS Total_Premium_EGP,
    SUM(Claim_Amount) AS Total_Claims_EGP,

    -- Loss ratio
    CAST(SUM(Claim_Amount) * 100.0 / NULLIF(SUM(Annual_Premium), 0) AS DECIMAL(6,2)) AS Overall_Loss_Ratio_Pct,

    -- Claim frequency
    CAST(SUM(CASE WHEN Claim_Amount > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)  AS DECIMAL(5,1)) AS Claim_Frequency_Pct,

    -- Churn
    CAST(SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
                  THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
         AS DECIMAL(5,1)) AS Churn_Rate_Pct,

    -- Revenue at risk
    SUM(CASE WHEN Status IN ('Lapsed','Cancelled')
             THEN Annual_Premium ELSE 0 END) AS Revenue_At_Risk_EGP,

    -- Average metrics
    CAST(AVG(CAST(Annual_Premium AS FLOAT))
         AS DECIMAL(10,2)) AS Avg_Premium_EGP,
    CAST(AVG(CASE WHEN Claim_Amount > 0
                  THEN CAST(Claim_Amount AS FLOAT) END)
         AS DECIMAL(10,2)) AS Avg_Claim_Claimants_EGP,

    -- High-risk concentration
    SUM(CASE WHEN Claim_Amount > 60000 THEN 1 ELSE 0 END) AS Outlier_Claims_Count,
    SUM(CASE WHEN Claim_Amount > 60000
             THEN Claim_Amount ELSE 0 END) AS Outlier_Claims_Total_EGP
FROM dbo.Insurance_Claims;
GO

-- Query the KPI view
SELECT * FROM dbo.vw_Insurance_KPIs;
GO



   -- CLEANUP
DROP TABLE IF EXISTS CustomerSegments;
GO

/* ============================================================
   END OF SCRIPT
   ============================================================

   QUICK REFERENCE — SECTION INDEX
   ─────────────────────────────────────────────────────────
   01.A  Row count & date range
   01.B  NULL audit
   01.C  Claim distribution flags
   01.D  Categorical frequencies

   02.A  Overall Loss Ratio
   02.B  Loss Ratio by Policy_Type        ← Pricing lever
   02.C  Loss Ratio by Chronic_Diseases   ← Underwriting signal
   02.D  Loss Ratio by Age Band           ← Age-band pricing
   02.E  Cross-tab Policy_Type × Chronic  ← 3×3 matrix
   02.F  Top 20 outlier claims            ← Pareto check
   02.G  Cumulative loss concentration    ← 80/20 rule
   02.H  YoY Loss Ratio trend

   03.A  Overall churn rate
   03.B  Churn by Policy_Type
   03.C  Churn by Age Band
   03.D  Churn by Days_Since_Renewal      ← Strongest predictor
   03.E  Churn by Claim behavior
   03.F  Chronic × Status interaction
   03.G  Lapsed at risk of cancellation   ← Intervention list
   03.H  Revenue at risk from churn

   04.A  Risk Score build (CTE)
   04.B  Segment size & financial profile
   04.C  Suggested premium re-pricing
   04.D  Segment heatmap by Policy_Type
   04.E  Segment × Chronic interaction
   04.F  Full customer profile with tags  ← Use for reporting

   05    Executive KPI Summary View (vw_Insurance_KPIs)
   ─────────────────────────────────────────────────────────
============================================================ */
   CLEANUP
   ============================================================ */
DROP TABLE IF EXISTS CustomerSegments;
GO