SELECT * FROM customers_transactions.customers_final;
UPDATE customers_final SET Gender = NULL WHERE Gender = '';
UPDATE customers_final SET Age = NULL WHERE Age = '';
Alter table customers_final modify age int null;

CREATE TABLE Transactions 
(date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL(10,2));

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS.csv"
INTO TABLE TRANSACTIONS 
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW VARIABLES LIKE 'secure_file_priv';

SELECT * FROM transactions;

-- ЧАСТЬ 1 - Клиенты с непрерывной историей
---- 1.1 Клиенты с 12 месяцами активности
SELECT ID_client
FROM Transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY ID_client
HAVING COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) = 12;

-- 1.2 Основные метрики по клиентам
SELECT 
    t.ID_client,
    AVG(t.Sum_payment) AS avg_check,
    SUM(t.Sum_payment) / COUNT(DISTINCT DATE_FORMAT(t.date_new, '%Y-%m')) AS avg_monthly_spend,
    COUNT(t.Id_check) AS total_operations
FROM Transactions t
JOIN (
    SELECT ID_client
    FROM Transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client
    HAVING COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) = 12
) fc
ON t.ID_client = fc.ID_client
GROUP BY t.ID_client;

-- 1.3 Помесячная детализация
SELECT 
    t.ID_client,
    DATE_FORMAT(t.date_new, '%Y-%m') AS month,
    AVG(t.Sum_payment) AS avg_check_month,
    COUNT(t.Id_check) AS operations_month,
    SUM(t.Sum_payment) AS total_month
FROM Transactions t
JOIN (
    SELECT ID_client
    FROM Transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client
    HAVING COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) = 12
) fc
ON t.ID_client = fc.ID_client
GROUP BY t.ID_client, month;

-- ЧАСТЬ 2 - Метрики по месяцам
-- 2.1 Средний чек в месяц
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    AVG(Sum_payment) AS avg_check
FROM Transactions
GROUP BY month;

-- 2.2 Среднее количество операций
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    COUNT(Id_check) AS total_operations
FROM Transactions
GROUP BY month;

-- 2.3 Количество активных клиентов
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    COUNT(DISTINCT ID_client) AS active_clients
FROM Transactions
GROUP BY month;

-- 2.4 Доля операций
-- доля от общего числа операций
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    COUNT(*) / (SELECT COUNT(*) FROM Transactions) AS share_operations
FROM Transactions
GROUP BY month;

-- доля от суммы
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    SUM(Sum_payment) / (SELECT SUM(Sum_payment) FROM Transactions) AS share_revenue
FROM Transactions
GROUP BY month;

-- 2.5 Гендерный анализ (M/F/NA)
SELECT 
    DATE_FORMAT(t.date_new, '%Y-%m') AS month,
    c.Gender,
    COUNT(*) AS operations,
    SUM(t.Sum_payment) AS total_spent,
    SUM(t.Sum_payment) / SUM(SUM(t.Sum_payment)) OVER (PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m')) AS share_spent
FROM Transactions t
JOIN customers_final c 
    ON t.ID_client = c.Id_client
GROUP BY month, c.Gender;

-- ЧАСТЬ 3 - Возрастные группы
-- 3.1 Общие показатели по возрасту
SELECT 
    age_group,
    COUNT(Id_check) AS total_operations,
    SUM(Sum_payment) AS total_amount
FROM (
    SELECT 
        t.Id_check,
        t.Sum_payment,
        CASE 
            WHEN c.age IS NULL THEN 'NA'
            WHEN c.age < 10 THEN '0-9'
            WHEN c.age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.age BETWEEN 50 AND 59 THEN '50-59'
            ELSE '60+'
        END AS age_group
    FROM Transactions t
    JOIN customers_final c
        ON t.ID_client = c.Id_client
) sub
GROUP BY age_group;

-- 3.2 Поквартальная аналитика
SELECT 
    age_group,
    QUARTER(date_new) AS quarter,
    COUNT(Id_check) AS operations,
    AVG(Sum_payment) AS avg_check,
    SUM(Sum_payment) AS total_amount
FROM (
    SELECT 
        t.date_new,
        t.Id_check,
        t.Sum_payment,
        CASE 
            WHEN c.age IS NULL THEN 'NA'
            WHEN c.age < 10 THEN '0-9'
            WHEN c.age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.age BETWEEN 50 AND 59 THEN '50-59'
            ELSE '60+'
        END AS age_group
    FROM Transactions t
    JOIN customers_final c
        ON t.ID_client = c.Id_client
) sub
GROUP BY age_group, quarter;

-- 3.3 Доля по возрастным группам
SELECT 
    age_group,
    SUM(Sum_payment) / SUM(SUM(Sum_payment)) OVER () AS share_total
FROM (
    SELECT 
        t.Sum_payment,
        CASE 
            WHEN c.age IS NULL THEN 'NA'
            WHEN c.age < 10 THEN '0-9'
            WHEN c.age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.age BETWEEN 50 AND 59 THEN '50-59'
            ELSE '60+'
        END AS age_group
    FROM Transactions t
    JOIN customers_final c
        ON t.ID_client = c.Id_client
) sub
GROUP BY age_group;
