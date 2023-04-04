--1. Выбрать из реестра договоров все договоры аренды имущества, заключённые в 2015 году, 
--по которым тип арендуемого объекта – Сооружение. В запросе вывести: номер лицевого счёта,
--номер договора, дату договора, тип объекта, адрес объекта, тип контрагента,
--наименование контрагента.

SELECT DISTINCT
    RA.ACCOUNT_NUMBER, --номер лицевого счёта
	RD.DOG_NO, --номер договора
	RD.DOG_DATE, --дату договора
	RO.TYPE_NAME, --наименование типа объекта
	(SELECT STUFF(CAST((SELECT [text()] =', '+ "OB".ADRESS 
	FROM (select distinct ROBJECT.ADRESS as ADRESS from ROBJECT 
	WHERE ROBJECT.OBJECT_ID in
	(SELECT ORELATION.OBJECT_ID 
	FROM ORELATION 
	WHERE ORELATION.DOGOVOR_ID = RD.DOGOVOR_ID and ORELATION.document_id isnull
	AND ORELATION.DATE_END isnull)) "OB" FORXMLPATH(''),TYPE)ASVARCHAR(max)), 1, 2,''))as adrs_obj, --адрес объекта
	(SELECT TOP 1 RCONTRAGENT.type_id
	FROM RCONTRAGENT 
	WHERE RCONTRAGENT.CONTRAGENT_ID in
	(SELECT ORE.CONTRAGENT_ID
	FROM ORELATION ORE 
	JOIN UACCOUNT_RELATION UACC on UACC.RELATION_ID = ORE.RELATION_ID
	WHERE UACC.ACCOUNT_ID = RA.ACCOUNT_ID 
	AND ISNULL(uacc.IS_EXCLUDED,0)<>1 )) as TYPE_C, --тип контрагента
	RC.TYPE_NAME, -- наименование типа
	RD.NAME, --наименование договора
    RD.DATEIN,
	ISNULL(RC.FULLNAME,RC.NAME)ContrName, -- наименование контрагента
	OR1.CONTRAGENT_ID
	FROM RDOGOVOR RD
	LEFT JOIN ORELATION OR1 ON OR1.DOGOVOR_ID = RD.DOGOVOR_ID 
	LEFT JOIN ROBJECT  RO ON OR1.OBJECT_ID= RO.OBJECT_ID
	LEFT JOIN RCONTRAGENT RC ON RC.CONTRAGENT_ID = OR1.CONTRAGENT_ID 
	LEFT JOIN RACCOUNT RA ON RA.DOGOVOR_ID = RD.DOGOVOR_ID
	JOIN SREESTR_TYPE SR ON RO.TYPE_ID= SR.TYPE_ID
	WHERE SR.TYPE_NAME='Сооружение'and RD.DATEIN between'01.01.2015'and'31.12.2015'

-- 2.Выбрать из реестра Контрагентов ИНН и Наименования контрагентов, 
--по которым в реестре Договоров есть договор аренды земельного участка 
--(выбрать данные договоры аренды земельного участка необходимо по типу договора). 
--Добавить условия по правоотношениям: учитывать только аренду и незавершённые правоотношения.
--Вывести в запрос количество объектов по каждому из договоров.

SELECT DISTINCT
    RD.NAME, -- Наименования договора
	RC.NAME, -- Наименования контрагентов
    RC.INN, -- ИНН
	SR.TYPE_NAME, -- тип договора
    (SELECT COUNT(ore.OBJECT_ID)
	FROM orelation ORE
	WHERE ore.DATE_END ISNULL AND ORE.DOGOVOR_ID = RD.DOGOVOR_ID) ObjCount -- количество объектов
	FROM ORELATION OR1 
	INNER JOIN RCONTRAGENT RC ON OR1.CONTRAGENT_ID = RC.CONTRAGENT_ID 
	JOIN RDOGOVOR RD ON OR1.DOGOVOR_ID = RD.DOGOVOR_ID
	JOIN SREESTR_TYPE SR ON RC.TYPE_ID= SR.TYPE_ID and SR.REESTR_TABLE ='RCONTRAGENT'
	WHERE RD.NAME='Аренда земельного участка'and RC.INN ISNOTNULL and RC.ACTIVE=1

--3.Вывести сумму годовой арендной платы и среднюю арендуемую площадь по всем многообъектным договорам.

SELECT
    SUM(A_YEAR)AS [годовая сумма обязательств],
	AVG(PL_DOG)AS [Средняя арендная площадь],
	COUNT(IS_MULTI_OBJECT)AS [Количество договоров]
	FROM RDOGOVOR
	WHERE IS_MULTI_OBJECT ='true'

--4.По всем договорам аренды земельных участков вывести
-- Номер и дату договора, а также информацию из последнего 
-- документа - основания начислений с методикой расчёта «От кадастровой стоимости»:
-- Начало действия, Окончание действия, Методику расчёта, Кадастровую стоимость, 
-- Процент от кадастровой стоимости.

SELECT DISTINCT
    RD.NAME, --Наименование договора
    RD.DOG_NO, --Номер договора
    RD.DOG_DATE, --Дата договора
    UC.PERIOD_BEG,--Начало действия
	UC.PERIOD_END, --Конец действия
	UC.NAME, --Основание начисления
	UC.SCALC_METHOD, -- наименование методики расчета
	(SELECT TOP 1 OCA.KAD_ST 
	FROM ORELATION O 
	LEFTJOIN UCALC_DOC_RELATION UCA ON UCA.RELATION_ID = O.RELATION_ID
	LEFTJOIN OCALC_DOC_PARAM OCA ON OCA.CALC_DOC_PARAM_ID = UCA.CALC_DOC_PARAM_ID
	WHERE O.DOGOVOR_ID = RD.DOGOVOR_ID ORDERBY OCA.PERIOD_BEG DESC) KAD_ST, --кадастровая стоимость

	(SELECT TOP 1 CAST (OCA.PR_KAD ASFLOAT)
	FROM ORELATION O 
	LEFTJOIN UCALC_DOC_RELATION UCA ON UCA.RELATION_ID = O.RELATION_ID 
	LEFTJOIN OCALC_DOC_PARAM OCA ON OCA.CALC_DOC_PARAM_ID = UCA.CALC_DOC_PARAM_ID
	WHERE O.DOGOVOR_ID = RD.DOGOVOR_ID ORDERBY OCA.PERIOD_BEG DESC) PR_KAD --процент от кадастровой стоимости

	FROM RDOGOVOR RD
	LEFT JOIN ORELATION OR1 ON OR1.DOGOVOR_ID = RD.DOGOVOR_ID 
	LEFT JOIN UACCOUNT_RELATION UA ON OR1.RELATION_ID = UA.RELATION_ID
	LEFT JOIN RACCOUNT RA ON UA.ACCOUNT_ID = RA.ACCOUNT_ID
	LEFT JOIN UCALC_DOC_RELATION UC ON OR1.RELATION_ID = UC.RELATION_ID 
	LEFT JOIN ROPERATION RO ON RA.ACCOUNT_ID = RO.ACCOUNT_ID,
	WHERE UC.RELATION_ID ='535CA418-34A6-467D-9CB2-FD09404000EA'
	ORDER BY UC.PERIOD_BEG DESC

-- 5.Вывести в запросе номер лицевого счета, номер договора, дата договора,
-- Наим.Арендатора, начислено обязательств за период, оплачено обязательств за период.
-- Период: 2015 год

SELECT DISTINCT
	RA.ACCOUNT_NUMBER, -- номер лицевого счета
    RO.DEBET, --начислено обязательств
    RO.CREDIT, --оплачено обязательств 
	RD.DOG_NO, --Номер договора
	RD.DOG_DATE, --Дата договора
    RO.PERIOD_BEG, -- начало периода
    RO.PERIOD_END, -- конец периода
	(SELECTSTUFF(CAST((SELECT [text()] ='; '+ "AR".[NAME] 
	FROM (select distinct RCONTRAGENT.[NAME] as NAME
	from RCONTRAGENT 
	where RCONTRAGENT.CONTRAGENT_ID in
	(SELECT ORE.CONTRAGENT_ID
	FROM ORELATION ORE 
	JOIN UACCOUNT_RELATION UACC on UACC.RELATION_ID = ORE.RELATION_ID
	WHERE UACC.ACCOUNT_ID = RA.ACCOUNT_ID
	and ISNULL(uacc.IS_EXCLUDED,0)<>1 
	)) "AR" FORXMLPATH(''),TYPE)ASVARCHAR(max)), 1, 2,'')) ContrName --	Наименование арендатора	
	FROM RDOGOVOR RD 
	LEFT JOIN RACCOUNT RA on RA.DOGOVOR_ID = RD.DOGOVOR_ID
	LEFT JOIN ROPERATION RO on RO.ACCOUNT_ID = RA.ACCOUNT_ID
	LEFT JOIN SOPERATION_TYPE OP on OP.OPERATION_TYPE_ID = RO.OPERATION_TYPE_ID
	WHERE (RO.ACCOUNT_DATE) between '01.01.2015' and '31.12.2015'
	and (1=1) 
	ORDER BY RO.ACCOUNT_DATE DESC



