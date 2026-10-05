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
END;
GO

--2-- 
CREATE PROCEDURE HallarNumEmp @DNAME VARCHAR(14) 
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
            SELECT @NumEmp = COUNT(*) FROM EMP WHERE DEPTNO = @DEPTNO; 
            IF @NumEmp = 0 
            BEGIN 
                PRINT 'El departamento ''' + @DNAME + ''' no tiene empleados asignados.'; 
            END 
            ELSE 
            BEGIN 
                PRINT 'El departamento ''' + @DNAME + ''' tiene ' + CAST(@NumEmp AS VARCHAR) + ' empleado(s).'; 
            END 
        END 
    END TRY 
    BEGIN CATCH 
        PRINT 'Excepción capturada: ' + ERROR_MESSAGE(); 
    END CATCH 
END;
GO

--3-- 
CREATE FUNCTION CalcularCosteSalarial (@DNAME VARCHAR(14)) 
RETURNS DECIMAL(10,2) 
AS 
BEGIN 
    DECLARE @DEPTNO INT; 
    DECLARE @CosteTotal DECIMAL(10,2); 
    SET @DEPTNO = dbo.DevolverCodDept(@DNAME); 
    
    IF @DEPTNO IS NULL 
    BEGIN 
        RETURN NULL; 
    END 
    
    SELECT @CosteTotal = ISNULL(SUM(SAL + ISNULL(COMM, 0)), 0) 
    FROM EMP 
    WHERE DEPTNO = @DEPTNO; 
    
    RETURN @CosteTotal; 
END;
GO

--4-- 
CREATE PROCEDURE MostrarCostesSalariales 
AS 
BEGIN 
    DECLARE @DNAME VARCHAR(14); 
    DECLARE @Coste DECIMAL(10,2); 
    DECLARE cDept CURSOR FOR SELECT DNAME FROM DEPT; 
    
    BEGIN TRY 
        OPEN cDept; 
        FETCH NEXT FROM cDept INTO @DNAME; 
        
        WHILE @@FETCH_STATUS = 0 
        BEGIN 
            SET @Coste = dbo.CalcularCosteSalarial(@DNAME); 
            IF @Coste IS NULL 
            BEGIN 
                PRINT 'Departamento ' + @DNAME + ': sin datos de coste.'; 
            END 
            ELSE 
            BEGIN 
                PRINT 'Departamento ' + @DNAME + ' | Coste salarial total: ' + CAST(@Coste AS VARCHAR) + ' euros'; 
            END 
            
            FETCH NEXT FROM cDept INTO @DNAME; 
        END 
        
        CLOSE cDept; 
        DEALLOCATE cDept; 
    END TRY 
    BEGIN CATCH 
        IF CURSOR_STATUS('global','cDept') >= 0 OR CURSOR_STATUS('local','cDept') >= 0 
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
    DECLARE @ENAME VARCHAR(10); 
    DECLARE @Abreviatura VARCHAR(3); 
    DECLARE cEmp CURSOR FOR SELECT ENAME FROM EMP; 
    
    BEGIN TRY 
        OPEN cEmp; 
        FETCH NEXT FROM cEmp INTO @ENAME; 
        
        WHILE @@FETCH_STATUS = 0 
        BEGIN 
            SET @Abreviatura = LEFT(@ENAME, 3); 
            PRINT 'Empleado: ' + @ENAME + ' | Abreviatura: ' + @Abreviatura; 
            FETCH NEXT FROM cEmp INTO @ENAME; 
        END 
        
        CLOSE cEmp; 
        DEALLOCATE cEmp; 
    END TRY 
    BEGIN CATCH 
        IF CURSOR_STATUS('global','cEmp') >= 0 OR CURSOR_STATUS('local','cEmp') >= 0 
        BEGIN 
            CLOSE cEmp; 
            DEALLOCATE cEmp; 
        END 
        PRINT 'Excepción capturada: ' + ERROR_MESSAGE(); 
    END CATCH 
END;
GO

--6-- 
CREATE PROCEDURE MostrarMasAntiguos 
AS 
BEGIN 
    DECLARE @DEPTNO INT; 
    DECLARE @DNAME VARCHAR(14); 
    DECLARE @ENAME VARCHAR(10); 
    DECLARE @HIREDATE DATE; 
    DECLARE cDept CURSOR FOR SELECT DEPTNO, DNAME FROM DEPT; 
    
    BEGIN TRY 
        OPEN cDept; 
        FETCH NEXT FROM cDept INTO @DEPTNO, @DNAME; 
        
        WHILE @@FETCH_STATUS = 0 
        BEGIN 
            SELECT TOP 1 @ENAME = ENAME, @HIREDATE = HIREDATE 
            FROM EMP 
            WHERE DEPTNO = @DEPTNO 
            ORDER BY HIREDATE ASC; 
            
            IF @@ROWCOUNT = 0 
            BEGIN 
                PRINT 'Departamento: ' + @DNAME + ' | No tiene empleados.'; 
            END 
            ELSE 
            BEGIN 
                PRINT 'Departamento: ' + @DNAME + ' | Empleado más antiguo: ' + @ENAME + ' (Contratado: ' + CAST(@HIREDATE AS VARCHAR) + ')'; 
            END 
            
            FETCH NEXT FROM cDept INTO @DEPTNO, @DNAME; 
        END 
        
        CLOSE cDept; 
        DEALLOCATE cDept; 
    END TRY 
    BEGIN CATCH 
        IF CURSOR_STATUS('global','cDept') >= 0 OR CURSOR_STATUS('local','cDept') >= 0 
        BEGIN 
            CLOSE cDept; 
            DEALLOCATE cDept; 
        END 
        PRINT 'Excepción capturada: ' + ERROR_MESSAGE(); 
    END CATCH 
END;
GO

--7-- 
CREATE PROCEDURE MostrarJefes @DNAME VARCHAR(14) 
AS 
BEGIN 
    DECLARE @DEPTNO INT; 
    DECLARE @ENAME VARCHAR(10); 
    DECLARE @ContadorJefes INT = 0; 
    
    BEGIN TRY 
        SET @DEPTNO = dbo.DevolverCodDept(@DNAME); 
        
        IF @DEPTNO IS NULL 
        BEGIN 
            RAISERROR('El departamento ''%s'' no existe en la base de datos.', 16, 1, @DNAME); 
        END 
        
        DECLARE cJefes CURSOR FOR 
            SELECT DISTINCT E.ENAME 
            FROM EMP E 
            WHERE E.DEPTNO = @DEPTNO 
              AND E.EMPNO IN (SELECT DISTINCT MGR FROM EMP WHERE MGR IS NOT NULL); 
              
        OPEN cJefes; 
        FETCH NEXT FROM cJefes INTO @ENAME; 
        PRINT 'Jefes del departamento ' + @DNAME + ':'; 
        
        WHILE @@FETCH_STATUS = 0 
        BEGIN 
            PRINT ' - ' + @ENAME; 
            SET @ContadorJefes = @ContadorJefes + 1; 
            FETCH NEXT FROM cJefes INTO @ENAME; 
        END 
        
        IF @ContadorJefes = 0 
        BEGIN 
            PRINT 'No hay empleados en este departamento que sean jefes de otros.'; 
        END 
        
        CLOSE cJefes; 
        DEALLOCATE cJefes; 
    END TRY 
    BEGIN CATCH 
        IF CURSOR_STATUS('global','cJefes') >= 0 OR CURSOR_STATUS('local','cJefes') >= 0 
        BEGIN 
            CLOSE cJefes; 
            DEALLOCATE cJefes; 
        END 
        PRINT 'Excepción capturada: ' + ERROR_MESSAGE(); 
    END CATCH 
END;
GO

--8-- 
CREATE PROCEDURE MostrarMejoresVendedores 
AS 
BEGIN 
    DECLARE @ENAME VARCHAR(10); 
    DECLARE @COMM DECIMAL(7,2); 
    DECLARE @Posicion INT = 1; 
    DECLARE cVendedores CURSOR FOR 
        SELECT TOP 2 ENAME, ISNULL(COMM, 0) AS COMM 
        FROM EMP 
        WHERE JOB = 'SALESMAN' 
        ORDER BY ISNULL(COMM, 0) DESC; 
        
    BEGIN TRY 
        OPEN cVendedores; 
        FETCH NEXT FROM cVendedores INTO @ENAME, @COMM; 
        PRINT '--- Top 2 Vendedores con más Comisiones ---'; 
        
        WHILE @@FETCH_STATUS = 0 
        BEGIN 
            PRINT CAST(@Posicion AS VARCHAR) + 'º Lugar: ' + @ENAME + ' | Comisión: ' + CAST(@COMM AS VARCHAR) + ' euros'; 
            SET @Posicion = @Posicion + 1; 
            FETCH NEXT FROM cVendedores INTO @ENAME, @COMM; 
        END 
        
        IF @Posicion = 1 
        BEGIN 
            PRINT 'No hay vendedores registrados en la base de datos.'; 
        END 
        
        CLOSE cVendedores; 
        DEALLOCATE cVendedores; 
    END TRY 
    BEGIN CATCH 
        IF CURSOR_STATUS('global','cVendedores') >= 0 OR CURSOR_STATUS('local','cVendedores') >= 0 
        BEGIN 
            CLOSE cVendedores; 
            DEALLOCATE cVendedores; 
        END 
        PRINT 'Excepción capturada: ' + ERROR_MESSAGE(); 
    END CATCH 
END;
GO

--10-- 
CREATE PROCEDURE RecortarSueldos @Letra CHAR(1) 
AS 
BEGIN 
    DECLARE @FilasAfectadas INT; 
    BEGIN TRY 
        IF @Letra IS NULL OR LEN(@Letra) = 0 
        BEGIN 
            RAISERROR('Debe proporcionar una letra válida como parámetro.', 16, 1); 
        END 
        
        UPDATE EMP 
        SET SAL = SAL * 0.80 
        WHERE ENAME LIKE @Letra + '%'; 
        
        SET @FilasAfectadas = @@ROWCOUNT; 
        
        IF @FilasAfectadas = 0 
        BEGIN 
            PRINT 'No se encontraron empleados cuyo nombre empiece por la letra ''' + @Letra + '''.'; 
        END 
        ELSE 
        BEGIN 
            PRINT 'Se ha recortado el sueldo un 20% a ' + CAST(@FilasAfectadas AS VARCHAR) + ' empleado(s) que empiezan por ''' + @Letra + '''.'; 
        END 
    END TRY 
    BEGIN CATCH 
        PRINT 'Excepción capturada: ' + ERROR_MESSAGE(); 
    END CATCH 
END;
GO

--11-- 
CREATE PROCEDURE BorrarBecarios 
AS 
BEGIN 
    DECLARE @DEPTNO INT; 
    DECLARE @DNAME VARCHAR(14); 
    DECLARE @EMPNO INT; 
    DECLARE @ENAME VARCHAR(10); 
    DECLARE @TotalBorrados INT = 0; 
    DECLARE cDept CURSOR FOR SELECT DEPTNO, DNAME FROM DEPT; 
    
    BEGIN TRY 
        OPEN cDept; 
        FETCH NEXT FROM cDept INTO @DEPTNO, @DNAME; 
        
        WHILE @@FETCH_STATUS = 0 
        BEGIN 
            DECLARE cBecarios CURSOR FOR 
                SELECT TOP 2 EMPNO, ENAME 
                FROM EMP 
                WHERE DEPTNO = @DEPTNO 
                ORDER BY HIREDATE DESC; 
                
            OPEN cBecarios; 
            FETCH NEXT FROM cBecarios INTO @EMPNO, @ENAME; 
            
            WHILE @@FETCH_STATUS = 0 
            BEGIN 
                DELETE FROM EMP WHERE EMPNO = @EMPNO; 
                PRINT 'Borrado el empleado ' + @ENAME + ' (ID: ' + CAST(@EMPNO AS VARCHAR) + ') del departamento ' + @DNAME; 
                SET @TotalBorrados = @TotalBorrados + 1; 
                FETCH NEXT FROM cBecarios INTO @EMPNO, @ENAME; 
            END 
            
            CLOSE cBecarios; 
            DEALLOCATE cBecarios; 
            
            FETCH NEXT FROM cDept INTO @DEPTNO, @DNAME; 
        END 
        
        CLOSE cDept; 
        DEALLOCATE cDept; 
        PRINT 'Proceso completado. Total de empleados borrados: ' + CAST(@TotalBorrados AS VARCHAR); 
    END TRY 
    BEGIN CATCH 
        IF CURSOR_STATUS('global','cBecarios') >= 0 OR CURSOR_STATUS('local','cBecarios') >= 0 
        BEGIN 
            CLOSE cBecarios; 
            DEALLOCATE cBecarios; 
        END 
        IF CURSOR_STATUS('global','cDept') >= 0 OR CURSOR_STATUS('local','cDept') >= 0 
        BEGIN 
            CLOSE cDept; 
            DEALLOCATE cDept; 
        END 
        PRINT 'Excepción capturada: ' + ERROR_MESSAGE(); 
    END CATCH 
END;
GO