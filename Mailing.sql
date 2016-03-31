CREATE PROCEDURE JobStat

AS

/* ============================================================== */
-- блок переменных
DECLARE
    @EMAILS varchar(8000), -- лист рассылки
    @SQL varchar(max), -- рассылка (сформированное письмо)

    @JOB_RUN_DATE varchar(100), -- дата запуска джоба

    @BODY_MAIL_JOB varchar(max), -- тело письма в формате html
    @BODY_MAIL_DB varchar(max), -- свободное место
    @ATTACH_FILE nvarchar (100), -- список файлов для привязки к письму
    @TABLE_STAT_JOB varchar (max), -- формирование таблички для джобов

    @STR_ONE_REP varchar (max), -- отдельная строка для преобразования
	@COUNTER_POSITION int, -- counter позиций в строке
	@STR_TEMP varchar (max) -- новая сформированная строка

/* ============================================================== */

BEGIN

-- добавление файлов к письму
	SET @ATTACH_FILE = N'Здесь указываем ваш файл, который хотите прикрепить к письму (или даже файлы)';

-- получаем свободное место на диске (создаем две темповые таблички и вбиваем туда данные о дисках)
-- наш первый сервер, для которого узнаем информацию о дисках
	IF OBJECT_ID('tempdb..#tempServer1', 'U') IS NOT NULL DROP TABLE #tempServer1
	CREATE TABLE #tempServer1 (drive CHAR(1), freespace float)
	INSERT  INTO #tempServer1 EXEC master..xp_fixeddrives

-- наш второй сервер (для примера)
	IF OBJECT_ID('tempdb..#tempServer2', 'U') IS NOT NULL DROP TABLE #tempServer2
	CREATE TABLE #tempServer2 (drive CHAR(1), freespace float)
	INSERT  INTO #tempServer2 EXEC('exec master..xp_fixeddrives') at Server2

-- получаем список почтовой рассылки (все адреса по которым будет осуществляться рассылка, таблица MAIL_USER, у вас другая) )
	SELECT @EMAILS = LTRIM(STUFF((SELECT '; ' FROM MAIL_USER WHERE list_id=1 ORDER BY email FOR XML PATH('')),1,1,''));

-- здесь можем добавить внешние адреса для рассылки
	SET @EMAILS = @EMAILS + '; user1@mail.ru; user2@rambler.ru; user3@mail.ru';

-- получаем текущую дату
	SET @JOB_RUN_DATE = GETDATE();

-- получаем данные о свободном месте на серверах Server1 и Server2
	SET @BODY_MAIL_DB = '<p>
	<div><b>Данные о свободном месте на серверах</b></div>
	<br><table border = "1" bordercolor = "green">
	<tr>
		<td align = "center" colspan = "2"><b>Server #1</b></td>
	</tr>' +
	CAST((SELECT	td = 'диск ' + CONVERT(char(1), drive),'',
					td = 'свободно ' + CONVERT(varchar(10), ROUND(freespace/1024, 2)) + ' Гб'
		  FROM #tempServer1
		  FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX) ) +
	'<tr>
		<td align = "center" colspan = "2"><b>Server #2</b></td>
	</tr>' +
	CAST((SELECT	td = 'диск ' + CONVERT(char(1), drive),'',
					td = 'свободно ' + CONVERT(varchar(10), ROUND(freespace/1024, 2)) + ' Гб'
		  FROM #tempServer2
		  FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX) ) + '</table>
	</p>';

-- формирование таблицы для статистики джобов (таблица со всеми джобами JOBS, у вас другая)
	SET @TABLE_STAT_JOB = CAST(( SELECT	td = CONVERT(varchar(50), name),'',
										td = CONVERT(varchar(10), indate), '',
										td = CONVERT(varchar(1), run_status), ''
								 FROM JOBS WHERE indate = @JOB_RUN_DATE
								 FOR XML PATH('tr'), TYPE ) AS NVARCHAR(MAX) );

-- подсветка строки с неотработанным джобом (замена 1 и 0 на строковые эквиваленты)
	SET @TABLE_STAT_JOB = REPLACE(@TABLE_STAT_JOB, '<td>0</td>', '<td>NO</td>');
	SET @TABLE_STAT_JOB = REPLACE(@TABLE_STAT_JOB, '<td>1</td>', '<td>OK</td>');

-- подсветка строки с неотработавшим джобом (немного извращений) )
-- =============================================================================
	SET @STR_TEMP = '';
	SET @COUNTER_POSITION = 0;

	WHILE (LEN(@TABLE_STAT_JOB) > 0)
	BEGIN

		SET @STR_ONE_REP = SUBSTRING(@TABLE_STAT_JOB, 1, CHARINDEX('</tr>', @TABLE_STAT_JOB, 1) + 4);

		SET @COUNTER_POSITION = LEN(@STR_ONE_REP) + 1;

		IF (LEN(@TABLE_STAT_JOB) < @COUNTER_POSITION)
			SET @TABLE_STAT_JOB = SUBSTRING(@TABLE_STAT_JOB, @COUNTER_POSITION, LEN(@TABLE_STAT_JOB))
		ELSE
			SET @TABLE_STAT_JOB = SUBSTRING(@TABLE_STAT_JOB, @COUNTER_POSITION, (LEN(@TABLE_STAT_JOB)-@COUNTER_POSITION) + LEN(@STR_ONE_REP))

		IF (PATINDEX('%<td>NO</td>%', @STR_ONE_REP)) != 0 SET @STR_ONE_REP = REPLACE(@STR_ONE_REP, '<tr>', '<tr bgcolor = "red">');

		SET @STR_TEMP = @STR_TEMP + @STR_ONE_REP;
	END
-- =============================================================================

-- формируем тело письма для отправки
	SET @BODY_MAIL_JOB = '<p>
	<div><b>Анализ выполнения джобов</b></div>

    <br><table border = "1" bordercolor = "green">
    <tr>
		<td align = "center"><b>Имя джоба</b></td>
		<td align = "center"><b>Дата выполнения</b></td>
		<td align = "center"><b>Статус выполнения</b></td>
    </tr>' + @STR_TEMP + '</table></p>';

-- настройка параметров для отправки почты (имя нашей ранее созданной учетной записи для рассылки - TestProfile, вы могли другое указать)
	SET @SQL = 'exec msdb.dbo.sp_send_dbmail
	@profile_name = ''TestProfile'',
	@recipients = ''' + @EMAILS + ''',
	@reply_to = ''ghostrider.gu@gmail.com'',
	@subject = ''Анализ джобов'+@JOB_RUN_DATE+' '',
	@body_format = ''HTML'',
	@body = '' '+ @BODY_MAIL_JOB + @BODY_MAIL_DB +' '',
	@importance = ''High'',
	@file_attachments='+char(39)+@ATTACH_FILE+char(39);

-- выполняем отправку почты на указанные адреса
	EXEC(@SQL);

END