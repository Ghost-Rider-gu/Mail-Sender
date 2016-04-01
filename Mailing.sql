CREATE PROCEDURE JobStat

AS

/* ============================================================== */
-- variables block
DECLARE
    @EMAILS varchar(8000), -- mailing list
    @SQL varchar(max),     -- delivery (formed by a letter)

    @JOB_RUN_DATE varchar(100), -- job launch date

    @BODY_MAIL_JOB varchar(max),   -- body of the message in html format
    @BODY_MAIL_DB varchar(max),    -- free place
    @ATTACH_FILE nvarchar (100),   -- a list of files to be attached to the letter
    @TABLE_STAT_JOB varchar (max), -- the formation of plaques for jobs

    @STR_ONE_REP varchar (max), -- a separate line for conversion
	  @COUNTER_POSITION int,      -- position in line
	  @STR_TEMP varchar (max)     -- formed a new line
/* ============================================================== */

BEGIN

-- addition to writing files
	SET @ATTACH_FILE = N'Here, specify your file you want to attach to the letter (or files)';

-- get the free space on the disk (create two tempo signs and trying to drive to get data on the disks)
-- our first server for which you will learn information about disks
	IF OBJECT_ID('tempdb..#tempServer1', 'U') IS NOT NULL DROP TABLE #tempServer1
	CREATE TABLE #tempServer1 (drive CHAR(1), freespace float)
	INSERT  INTO #tempServer1 EXEC master..xp_fixeddrives

-- our second server (for example)
	IF OBJECT_ID('tempdb..#tempServer2', 'U') IS NOT NULL DROP TABLE #tempServer2
	CREATE TABLE #tempServer2 (drive CHAR(1), freespace float)
	INSERT  INTO #tempServer2 EXEC('exec master..xp_fixeddrives') at Server2

-- get your mailing list (all of which will address carried mail, table MAIL_USER, you have the other)
	SELECT @EMAILS = LTRIM(STUFF((SELECT '; ' FROM MAIL_USER WHERE list_id=1 ORDER BY email FOR XML PATH('')),1,1,''));

-- here we can add external addresses for mailing
	SET @EMAILS = @EMAILS + '; user1@mail.ru; user2@rambler.ru; user3@mail.ru';

-- get the current date
	SET @JOB_RUN_DATE = GETDATE();

-- obtain information about free space on servers Server1 and Server2
	SET @BODY_MAIL_DB = '<p>
	<div><b>Information about free space on servers</b></div>
	<br><table border = "1" bordercolor = "green">
	<tr>
		<td align = "center" colspan = "2"><b>Server #1</b></td>
	</tr>' +
	CAST((SELECT	td = 'disk ' + CONVERT(char(1), drive),'',
					td = 'free ' + CONVERT(varchar(10), ROUND(freespace/1024, 2)) + ' Gb'
		  FROM #tempServer1
		  FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX) ) +
	'<tr>
		<td align = "center" colspan = "2"><b>Server #2</b></td>
	</tr>' +
	CAST((SELECT	td = 'disk ' + CONVERT(char(1), drive),'',
					td = 'free ' + CONVERT(varchar(10), ROUND(freespace/1024, 2)) + ' Gb'
		  FROM #tempServer2
		  FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX) ) + '</table>
	</p>';

-- the formation of the table for jobs statistics (table with all jobs JOBS, you have the other)
	SET @TABLE_STAT_JOB = CAST(( SELECT	td = CONVERT(varchar(50), name),'',
										td = CONVERT(varchar(10), indate), '',
										td = CONVERT(varchar(1), run_status), ''
								 FROM JOBS WHERE indate = @JOB_RUN_DATE
								 FOR XML PATH('tr'), TYPE ) AS NVARCHAR(MAX) );

-- string lights with unspent jobs (replacement of 1 and 0 on the string equivalents)
	SET @TABLE_STAT_JOB = REPLACE(@TABLE_STAT_JOB, '<td>0</td>', '<td>NO</td>');
	SET @TABLE_STAT_JOB = REPLACE(@TABLE_STAT_JOB, '<td>1</td>', '<td>OK</td>');

-- string lights with unfinished jobs
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

-- form the body of the message to be sent
	SET @BODY_MAIL_JOB = '<p>
	<div><b>Performance analysis jobs</b></div>

    <br><table border = "1" bordercolor = "green">
    <tr>
		<td align = "center"><b>Job name</b></td>
		<td align = "center"><b>Date of completion</b></td>
		<td align = "center"><b>Performance status</b></td>
    </tr>' + @STR_TEMP + '</table></p>';

-- parameter setting is to send email (name of our previously created account to send - TestProfile, you might have a different point)
	SET @SQL = 'exec msdb.dbo.sp_send_dbmail
	@profile_name = ''TestProfile'',
	@recipients = ''' + @EMAILS + ''',
	@reply_to = ''ghostrider.gu@gmail.com'',
	@subject = ''Analysis jobs'+@JOB_RUN_DATE+' '',
	@body_format = ''HTML'',
	@body = '' '+ @BODY_MAIL_JOB + @BODY_MAIL_DB +' '',
	@importance = ''High'',
	@file_attachments='+char(39)+@ATTACH_FILE+char(39);

-- you are sending mail to a specified address
	EXEC(@SQL);

END