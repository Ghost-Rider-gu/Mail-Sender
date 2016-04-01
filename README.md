# Mailing-on-T-SQL
Implementation of mail in the language of T-SQL


This example shows how to clean the T-SQL do mailings.
To post dispatch earned, it is necessary (open MS SQL Server Management Studio):

1. Configure the component
2. Create a job and adjust the time of its implementation (as triggered actions indicate our procedure, for example EXEC dbo.MyProcedure).

The code is the code of procedure for the analysis of jobs work. Administrator or other person in charge will come a letter with the results of jobs.
Of course, the procedure can be designed differently to make some things in parameters (for example attachable files, e-mail addresses).