-- Проверяем наличие объекта
create procedure syn.usp_ImportFileCustomerSeasonal
	-- При наличии только одного параметра, этот параметр пишется на строке выполнения
	@ID_Record int
as
set nocount on
begin
	-- Все переменные задаются в одном объявлении
	--  Алиас обязателен для объекта
	declare @RowCount int = (select count(*) from syn.SA_CustomerSeasonal)
	declare @ErrorMessage varchar(max)

	-- Комментарий с таким же отступом как и код, к которому он относится
-- Проверка на корректность загрузки
	if not exists (
	-- В  условных операторах с одним условием весь блок с условиями смещается на один отступ
	select 1
	from syn.ImportFile as f
	where f.ID = @ID_Record
		and f.FlagLoaded = cast(1 as bit)
	)
		-- На одном уровне с `if` и `begin/end`
		begin
			set @ErrorMessage = 'Ошибка при загрузке файла, проверьте корректность данных'
			
			--  Пустыми строками отделяются разные логические блоки кода
			raiserror(@ErrorMessage, 3, 1)
			-- Пустая строка перед return 
			return
		end
	
	-- Проверяем наличие объекта
	-- Операторы и системные функции пишутся в нижнем регистре
	CREATE TABLE #ProcessedRows (
		-- Во всех созданных таблицах, кроме  SA  таблиц, обязательно наличие системных полей:  MDT_DateCreate ,  MDT_ID_PrincipalCreatedBy
		ActionType varchar(255),
		ID int
	)
	
	-- Между  --  и комментарием есть один пробел
	--Чтение из слоя временных данных
	select
		cc.ID as ID_dbo_Customer
		,cst.ID as ID_CustomerSystemType
		,s.ID as ID_Season
		,cast(cs.DateBegin as date) as DateBegin
		,cast(cs.DateEnd as date) as DateEnd
		,cd.ID as ID_dbo_CustomerDistributor
		,cast(isnull(cs.FlagActive, 0) as bit) as FlagActive
	into #CustomerSeasonal
	--  Алиас обязателен для объекта и задается с помощью ключевого слова as
	from syn.SA_CustomerSeasonal cs
		-- Все виды join указываются явно
		join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
		join dbo.Season as s on s.Name = cs.Season
		join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor
			and cd.ID_mapping_DataSource = 1
		-- При соединение двух таблиц, сперва после on указываем поле присоединяемой таблицы
		join syn.CustomerSystemType as cst on cs.CustomerSystemType = cst.Name
	where try_cast(cs.DateBegin as date) is not null
		and try_cast(cs.DateEnd as date) is not null
		and try_cast(isnull(cs.FlagActive, 0) as bit) is not null

	-- Определяем некорректные записи
	-- Добавляем причину, по которой запись считается некорректной
	select
		cs.*
		,case
			-- При написании конструкции с case, необходимо, чтобы when был под case с 1 отступом, then с 2 отступами
			when cc.ID is null then 'UID клиента отсутствует в справочнике "Клиент"'
			when cd.ID is null then 'UID дистрибьютора отсутствует в справочнике "Клиент"'
			when s.ID is null then 'Сезон отсутствует в справочнике "Сезон"'
			when cst.ID is null then 'Тип клиента в справочнике "Тип клиента"'
			when try_cast(cs.DateBegin as date) is null then 'Невозможно определить Дату начала'
			when try_cast(cs.DateEnd as date) is null then 'Невозможно определить Дату начала'
			when try_cast(isnull(cs.FlagActive, 0) as bit) is null then 'Невозможно определить Активность'
		end as Reason
	into #BadInsertedRows
	from syn.SA_CustomerSeasonal as cs
	--   Все виды join пишутся с 1 отступом
	left join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
		and cc.ID_mapping_DataSource = 1
	-- Если есть and, то выравнивать его на 1 табуляцию от join
	left join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor and cd.ID_mapping_DataSource = 1
	left join dbo.Season as s on s.Name = cs.Season
	left join syn.CustomerSystemType as cst on cst.Name = cs.CustomerSystemType
	where cc.ID is null
		or cd.ID is null
		or s.ID is null
		or cst.ID is null
		or try_cast(cs.DateBegin as date) is null
		or try_cast(cs.DateEnd as date) is null
		or try_cast(isnull(cs.FlagActive, 0) as bit) is null
		
end
