
USE SCOTT;
GO

--1--

CREATE FUNCTION DevolverCodDept (@DNAME VARCHAR(14)) 
RETURNS INT
AS
BEGIN 
	DECLARE @DEPTNO INT;
	SELECT @DEPTNO = DEPTNO FROM DEPT WHERE DNAME = @DNAME;
	RETURN @DEPTNO;
END
GO

--2--

CREATE PROCEDURE HallarNumEmp
@DNAME VARCHAR (14)
AS
BEGIN
	DECLARE @DEPTNO INT;
	DECLARE @NumEmp INT;
	BEGIN TRY
		SET @DEPTNO = dbo.DevolverCodDept(@DNAME);
		IF @DEPTNO IS NULL 
			BEGIN
				RAISERROR('El departamento ''%s'' no se ha encontrado en la base de datos.', 16, 1, @DNAME);
			END
		ELSE
			BEGIN
				SELECT @NumEmp = COUNT(*)
				FROM EMP
				WHERE DEPTNO = @DEPTNO;
			END
		IF @NumEmp = 0
			BEGIN
				PRINT 'El departamento ''' + @DNAME + ''' tiene ' + CAST(@NumEmp AS VARCHAR) + ' empleado(s).';
			END
	END TRY
	BEGIN CATCH
		PRINT 'Excepción capturada: ' + ERROR_MESSAGE();
	END CATCH
	END;
	GO

	--3--

	CREATE FUNCTION CalcularCosteSalarial(@DNAME VARCHAR(14))
	RETURNS DECIMAL(10,2)
	AS
	BEGIN
		DECLARE @DEPTNO INT;
		DECLARE @CosteTotal DECIMAL (10,2)
		SET @DEPTNO = dbo.DevolverCodDept(@DNAME)
		IF @DEPTNO IS NULL
			BEGIN
				RETURN NULL
			END
		SELECT @CosteTotal = ISNULL(SUM(SAL + ISNULL(COMM, 0)), 0)
		FROM EMP
		WHERE @DEPTNO = DEPTNO
		RETURN @CosteTotal;
	END;
	GO

	--4--

	CREATE PROCEDURE MostrarCostesSalariales
	AS 
	BEGIN
		DECLARE @DNAME VARCHAR(14);
		DECLARE @Coste DECIMAL(10,2);
		DECLARE cDept CURSOR 
		FOR SELECT DNAME
		FROM DEPT;
		BEGIN TRY
			OPEN cDept;
			FETCH NEXT FROM cDept INTO @DNAME;
			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @Coste = dbo.CalcularCosteSalarial(@DNAME)
					IF @Coste IS NULL
						BEGIN
							PRINT 'Departamento ' + @DNAME + ' sin datos de coste.';
						END
					ELSE
						BEGIN
							PRINT 'Departamento ' + @DNAME + '| Coste salarial total: ' + CAST(@Coste AS VARCHAR) + ' euros';
						END
					FETCH NEXT FROM cDept INTO @DNAME;
				END
			CLOSE cDept;
			DEALLOCATE cDept;
		END TRY
		BEGIN CATCH
			IF CURSOR_STATUS ('global','cDept') >= 0 or CURSOR_STATUS ('local','cDept') >= 0
				BEGIN
					CLOSE cDept;
					DEALLOCATE cDept;
				END
			PRINT 'Excepción capturada: ' + ERROR_MESSAGE();
		END CATCH
	END;
	GO

	--5--

	CREATE PROCEDURE MostrarAbreviaturas
	AS
	BEGIN
		DECLARE @ENAME