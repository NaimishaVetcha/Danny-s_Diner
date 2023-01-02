/*
CREATE SCHEMA dannys_diner;


CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

*/

SELECT * FROM SALES;
SELECT * FROM MENU;
SELECT * FROM MEMBERS;

-- What is the total amount each customer spent at the restaurant?
SELECT DISTINCT 
	S.CUSTOMER_ID, SUM(P.PRICE) OVER(PARTITION BY S.CUSTOMER_ID) AS AMOUNT_SPENT
FROM SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID;

-- (OR)

SELECT 
	S.CUSTOMER_ID, SUM(P.PRICE) AS AMOUNT_SPENT
FROM SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
GROUP BY S.CUSTOMER_ID;

-- How many days has each customer visited the restaurant?
SELECT 
	S.CUSTOMER_ID, COUNT(ORDER_DATE) AS VISITS
FROM SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
GROUP BY S.CUSTOMER_ID ;

-- (OR)

SELECT DISTINCT
	S.CUSTOMER_ID, COUNT(ORDER_DATE) OVER(PARTITION BY S.CUSTOMER_ID) AS VISITS
FROM SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID;

-- What was the first item from the menu purchased by each customer?
SELECT * FROM SALES;
	-- FIRST ITEM ORDERED
WITH CTE AS 
(SELECT
	S.*, P.PRODUCT_NAME,
	ROW_NUMBER() OVER(PARTITION BY S.CUSTOMER_ID ORDER BY S.ORDER_DATE) AS RN
FROM SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID)

SELECT CUSTOMER_ID, ORDER_DATE, PRODUCT_NAME FROM CTE WHERE RN = 1;

	-- ITEMS ORDERED ON FIRST DAY
WITH CTE AS 
(SELECT
	S.*, P.PRODUCT_NAME,
	DENSE_RANK() OVER(PARTITION BY S.CUSTOMER_ID ORDER BY S.ORDER_DATE) AS RN
FROM SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID)

SELECT CUSTOMER_ID, ORDER_DATE, PRODUCT_NAME FROM CTE WHERE RN = 1;

-- What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT 
	P.PRODUCT_NAME, COUNT(S.PRODUCT_ID) AS TIMES_ORDERED
FROM SALES S 
JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
GROUP BY P.PRODUCT_NAME 
ORDER BY COUNT(S.PRODUCT_ID) DESC 
OFFSET 0 ROWS FETCH FIRST 1 ROWS ONLY;

-- (OR)

SELECT TOP 1 
	P.PRODUCT_NAME, COUNT(S.PRODUCT_ID) AS TIMES_ORDERED
FROM SALES S 
JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
GROUP BY P.PRODUCT_NAME 
ORDER BY COUNT(S.PRODUCT_ID) DESC;

-- Which item was the most popular for each customer?
WITH TIMES_ORDERED AS 
(SELECT 
	S.CUSTOMER_ID, P.PRODUCT_NAME, COUNT(S.PRODUCT_ID) AS TIMES_ORDERED,  
	DENSE_RANK() OVER(PARTITION BY CUSTOMER_ID ORDER BY COUNT(S.PRODUCT_ID) DESC)  AS RN
FROM SALES S 
JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
GROUP BY S.CUSTOMER_ID, P.PRODUCT_NAME)

SELECT CUSTOMER_ID, PRODUCT_NAME, TIMES_ORDERED FROM TIMES_ORDERED WHERE RN = 1;
/* Note: Using same name for CTE as well as the calculated column is accepted, but should be careful while referring the cte or column name */
-- (OR)

WITH TIMES_ORDERED AS 
(SELECT DISTINCT
	S.CUSTOMER_ID, P.PRODUCT_NAME, COUNT(S.PRODUCT_ID) OVER (PARTITION BY S.CUSTOMER_ID, P.PRODUCT_NAME) AS ORDER_COUNT
FROM SALES S 
JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID),
TOP1 AS 
(SELECT 
	*,	DENSE_RANK() OVER(PARTITION BY CUSTOMER_ID ORDER BY ORDER_COUNT DESC) AS RN 
FROM TIMES_ORDERED)
SELECT CUSTOMER_ID, PRODUCT_NAME, ORDER_COUNT FROM TOP1 WHERE RN = 1;

-- Which item was purchased first by the customer after they became a member?
WITH CTE AS
(select 
	S.customer_id, P.product_name,	
	DENSE_RANK() OVER(PARTITION BY S.CUSTOMER_ID ORDER BY S.ORDER_DATE) AS RN  
from SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
LEFT JOIN MEMBERS M
ON S.CUSTOMER_ID = M.CUSTOMER_ID
WHERE S.ORDER_DATE >= M.JOIN_DATE)

SELECT * FROM CTE WHERE RN =1;

-- Which item was purchased just before the customer became a member?
WITH CTE AS
(select 
	S.customer_id, P.product_name, S.order_date, M.join_date, 	
	DENSE_RANK() OVER(PARTITION BY S.CUSTOMER_ID ORDER BY S.ORDER_DATE DESC) AS RN  
from SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
LEFT JOIN MEMBERS M
ON S.CUSTOMER_ID = M.CUSTOMER_ID
WHERE S.ORDER_DATE < M.JOIN_DATE)

SELECT * FROM CTE WHERE RN =1;

-- What is the total items and amount spent for each member before they became a member?
SELECT 
	S.CUSTOMER_ID, 
	COUNT(S.PRODUCT_ID) AS TOTAL_ITEMS,
	SUM(P.PRICE) AS PRICE
FROM SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
GROUP BY S.CUSTOMER_ID

--If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT DISTINCT 
	S.CUSTOMER_ID,
	SUM(CASE WHEN P.PRODUCT_NAME = 'SUSHI' THEN P.PRICE*20
	ELSE P.PRICE*10
	END) OVER(PARTITION BY S.CUSTOMER_ID) AS POINTS
FROM SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID;

-- (OR)

SELECT 
	S.CUSTOMER_ID,
	SUM(CASE WHEN P.PRODUCT_NAME = 'SUSHI' THEN P.PRICE*20
	ELSE P.PRICE*10
	END) AS POINTS
FROM SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
GROUP BY S.CUSTOMER_ID;

/* In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
	how many points do customer A and B have at the end of January? */
WITH CTE AS
(select 
	S.customer_id, 
	SUM(CASE WHEN S.ORDER_DATE BETWEEN M.JOIN_DATE AND dateadd(day, 7, M.JOIN_DATE) 
			 THEN P.PRICE*20 ELSE P.PRICE*10 END) AS POINTS
from SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
LEFT JOIN MEMBERS M
ON S.CUSTOMER_ID = M.CUSTOMER_ID
WHERE MONTH(S.ORDER_DATE) = MONTH(JOIN_DATE) 
GROUP BY S.CUSTOMER_ID)
SELECT * FROM CTE;

-- (OR)

SELECT DISTINCT
	S.customer_id,	SUM(CASE WHEN S.ORDER_DATE BETWEEN M.JOIN_DATE AND dateadd(day, 7, M.JOIN_DATE) 
								THEN P.PRICE*20 ELSE P.PRICE*10 END) OVER(PARTITION BY S.CUSTOMER_ID) AS POINTS
from SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
LEFT JOIN MEMBERS M
ON S.CUSTOMER_ID = M.CUSTOMER_ID
WHERE MONTH(S.ORDER_DATE) = MONTH(JOIN_DATE); 

-- Purchase history before and after membership
SELECT
	S.customer_id, S.order_date, P.product_name, P.PRICE,
	(CASE WHEN M.JOIN_DATE IS NULL OR M.JOIN_DATE > S.ORDER_DATE THEN 'N' ELSE 'Y' END) AS MEMBER
from SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
LEFT JOIN MEMBERS M
ON S.CUSTOMER_ID = M.CUSTOMER_ID;

--  Purchase ranking after membership
WITH CTE AS 
(SELECT
	S.customer_id, S.order_date, P.product_name, P.PRICE,
	(CASE WHEN M.JOIN_DATE IS NULL OR M.JOIN_DATE > S.ORDER_DATE THEN 'N' ELSE 'Y' END) AS MEMBER
from SALES S 
LEFT JOIN MENU P 
ON S.PRODUCT_ID = P.PRODUCT_ID
LEFT JOIN MEMBERS M
ON S.CUSTOMER_ID = M.CUSTOMER_ID)

SELECT *, NULL AS RANKING FROM CTE WHERE MEMBER = 'N'
UNION ALL
SELECT * , DENSE_RANK() OVER(PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) AS RANKING 
FROM CTE WHERE MEMBER = 'Y'
ORDER BY CUSTOMER_ID, ORDER_DATE;