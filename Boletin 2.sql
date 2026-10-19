-- 1. CREACIÓN Y SELECCIÓN DE BASE DE DATOS
CREATE DATABASE JUVENIL;
GO

USE JUVENIL;
GO

-- 2. CREACIÓN DE TABLAS
CREATE TABLE SOCIOS (
    DNI VARCHAR(10) CONSTRAINT PK_SOCIOS PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL,
    Direccion VARCHAR(100) NOT NULL,
    Penalizaciones INT DEFAULT 0
);
GO

CREATE TABLE LIBROS (
    RefLibro VARCHAR(10),
    Nombre VARCHAR(50) NOT NULL,
    Autor VARCHAR(50) NOT NULL,
    Genero VARCHAR(30) NOT NULL,
    AnioPublicacion INT,
    Editorial VARCHAR(30), -- Ampliado para admitir 'Sudamericana'

    CONSTRAINT PK_LIBROS PRIMARY KEY (RefLibro)
);
GO

CREATE TABLE PRESTAMOS (
    DNI VARCHAR(10),
    RefLibro VARCHAR(10),
    Fecha_Prestamo DATETIME2 NOT NULL,
    Duracion INT DEFAULT 24,

    CONSTRAINT PK_PRESTAMOS PRIMARY KEY (DNI, RefLibro, Fecha_Prestamo),
    CONSTRAINT FK_PRESTAMOS_SOCIOS FOREIGN KEY (DNI) REFERENCES SOCIOS(DNI),
    CONSTRAINT FK_PRESTAMOS_LIBROS FOREIGN KEY (RefLibro) REFERENCES LIBROS(RefLibro)
);
GO

-- 3. INSERCIÓN DE DATOS
-- Insertar Socios
INSERT INTO SOCIOS (DNI, Nombre, Direccion) 
VALUES 
('11111111A', 'Laura Gómez', 'Calle Mayor 12'), 
('22222222B', 'Carlos Ruiz', 'Av. Constitución 5'), 
('33333333C', 'Ana Martínez', 'Calle Norte 8');

-- Insertar Libros
INSERT INTO LIBROS (RefLibro, Nombre, Autor, Genero, AnioPublicacion, Editorial) 
VALUES 
('L01', 'El Hobbit', 'J.R.R. Tolkien', 'Fantasía', 1937, 'Minotauro'), 
('L02', '1984', 'George Orwell', 'Distopía', 1949, 'Debolsillo'), 
('L03', 'Fahrenheit 451', 'Ray Bradbury', 'Ciencia Ficción', 1953, 'Plaza'), 
('L04', 'Dune', 'Frank Herbert', 'Ciencia Ficción', 1965, 'Debolsillo'), 
('L05', 'Cien años de soledad', 'G. García Márquez', 'Novela', 1967, 'Sudamericana');

-- Insertar Préstamos
INSERT INTO PRESTAMOS (DNI, RefLibro, Fecha_Prestamo) 
VALUES 
('11111111A', 'L01', '2024-01-10'), 
('22222222B', 'L01', '2024-02-15'), 
('33333333C', 'L01', '2024-03-01'), 
('11111111A', 'L02', '2024-01-12'), 
('22222222B', 'L02', '2024-02-20'), 
('33333333C', 'L03', '2024-01-05'), 
('11111111A', 'L03', '2024-02-01'), 
('22222222B', 'L04', '2024-03-10');
GO

CREATE OR ALTER PROCEDURE listadocuatromasprestados
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. COMPROBACIÓN: TABLA LIBROS VACÍA
    IF NOT EXISTS (SELECT 1 FROM LIBROS)
    BEGIN
        RAISERROR ('Excepción: La tabla de libros está vacía.', 16, 1);
        RETURN;
    END;

    -- 2. COMPROBACIÓN: TABLA DE SOCIOS VACÍA
    IF NOT EXISTS (SELECT 1 FROM SOCIOS)
    BEGIN
        RAISERROR ('Excepción: La tabla de socios está vacía.', 16, 1);
        RETURN;
    END;

    -- 3. COMPROBACIÓN: HAY MENOS DE 4 LIBROS QUE HAYAN SIDO PRESTADOS
    DECLARE @NumLibrosPrestados INT;
    SELECT @NumLibrosPrestados = COUNT(DISTINCT RefLibro) FROM PRESTAMOS;

    IF @NumLibrosPrestados < 4
    BEGIN
        RAISERROR ('Excepción: Hay menos de 4 libros que hayan sido prestados.', 16, 1);
        RETURN;
    END;

    -- VARIABLES PARA CURSORES
    DECLARE @RefLibro VARCHAR(10), 
            @NombreLibro VARCHAR(50), 
            @Genero VARCHAR(30), 
            @NumPrestamos INT;

    DECLARE @DNI VARCHAR(10), 
            @FechaPrestamo DATETIME2;

    -- CURSOR PRINCIPAL: 4 LIBROS MÁS PRESTADOS
    DECLARE curLibros CURSOR FOR 
        SELECT TOP 4 L.RefLibro, L.Nombre, L.Genero, COUNT(P.RefLibro) AS NumPrestamos 
        FROM LIBROS L 
        INNER JOIN PRESTAMOS P ON L.RefLibro = P.RefLibro 
        GROUP BY L.RefLibro, L.Nombre, L.Genero 
        ORDER BY COUNT(P.RefLibro) DESC;

    OPEN curLibros; 
    FETCH NEXT FROM curLibros INTO @RefLibro, @NombreLibro, @Genero, @NumPrestamos; 

    WHILE @@FETCH_STATUS = 0 
    BEGIN
        -- IMPRIMIR CABECERA DEL LIBRO
        PRINT @NombreLibro + ' | ' + CAST(@NumPrestamos AS VARCHAR) + ' préstamos | ' + @Genero;

        -- CURSOR SECUNDARIO: PRÉSTAMOS DEL LIBRO ACTUAL
        DECLARE curPrestamos CURSOR FOR 
            SELECT DNI, Fecha_Prestamo 
            FROM PRESTAMOS 
            WHERE RefLibro = @RefLibro; 
            
        OPEN curPrestamos; 
        FETCH NEXT FROM curPrestamos INTO @DNI, @FechaPrestamo; 
        
        WHILE @@FETCH_STATUS = 0 
        BEGIN 
            PRINT '   DNI: ' + @DNI + ' - Fecha: ' + CONVERT(VARCHAR, @FechaPrestamo, 103); 
            FETCH NEXT FROM curPrestamos INTO @DNI, @FechaPrestamo; 
        END; 
        
        CLOSE curPrestamos; 
        DEALLOCATE curPrestamos;

        FETCH NEXT FROM curLibros INTO @RefLibro, @NombreLibro, @Genero, @NumPrestamos; 
    END; 

    CLOSE curLibros; 
    DEALLOCATE curLibros; 
END;
GO


CREATE OR ALTER PROCEDURE mostrar_rendimiento_modulo( IN ASIGNATURAS.NOMBRE%TYPE)
IS
    -- Excepciones personalizadas para el control de tablas y datos
    e_tabla_alumnos_vacia     EXCEPTION;
    e_tabla_asignaturas_vacia EXCEPTION;
    e_tabla_notas_vacia       EXCEPTION;
    e_modulo_no_existe        EXCEPTION;
    e_sin_alumnos_en_modulo   EXCEPTION;

    -- Variables de conteo de tablas y existencia de módulo
    v_total_alumnos     NUMBER;
    v_total_asignaturas NUMBER;
    v_total_notas       NUMBER;
    v_cod_modulo        ASIGNATURAS.COD%TYPE;

    -- Contadores de calificaciones
    v_suspensos      NUMBER := 0;
    v_aprobados      NUMBER := 0;
    v_notables       NUMBER := 0;
    v_sobresalientes NUMBER := 0;

    -- Variables para nota máxima y mínima
    v_nota_max NUMBER;
    v_nota_min NUMBER;

    -- Cursor con los alumnos matriculados en el módulo
    CURSOR c_alumnos (cp_cod ASIGNATURAS.COD%TYPE) IS
        SELECT a.APENOM, n.NOTA
        FROM NOTAS n
        JOIN ALUMNOS a ON n.DNI = a.DNI
        WHERE n.COD = cp_cod
        ORDER BY a.APENOM;

BEGIN
    -- 1. Comprobación de que las tablas contienen información
    SELECT COUNT(*) INTO v_total_alumnos FROM ALUMNOS;
    IF v_total_alumnos = 0 THEN
        RAISE e_tabla_alumnos_vacia;
    END IF;

    SELECT COUNT(*) INTO v_total_asignaturas FROM ASIGNATURAS;
    IF v_total_asignaturas = 0 THEN
        RAISE e_tabla_asignaturas_vacia;
    END IF;

    SELECT COUNT(*) INTO v_total_notas FROM NOTAS;
    IF v_total_notas = 0 THEN
        RAISE e_tabla_notas_vacia;
    END IF;

    -- 2. Comprobar que existe el módulo ingresado
    BEGIN
        SELECT COD 
        INTO v_cod_modulo
        FROM ASIGNATURAS
        WHERE UPPER(TRIM(NOMBRE)) = UPPER(TRIM(p_nombre_modulo));
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE e_modulo_no_existe;
    END;

    -- 3. Calcular la nota máxima y mínima para el módulo
    SELECT MAX(NOTA), MIN(NOTA)
    INTO v_nota_max, v_nota_min
    FROM NOTAS
    WHERE COD = v_cod_modulo;

    IF v_nota_max IS NULL THEN
        RAISE e_sin_alumnos_en_modulo;
    END IF;

    -- 4. Mostrar listado de alumnos y procesar estadísticas
    DBMS_OUTPUT.PUT_LINE('LISTADO DEL MÓDULO: ' || UPPER(p_nombre_modulo));
    DBMS_OUTPUT.PUT_LINE(RPAD('ALUMNO', 35) || 'NOTA');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 34, '-') || ' ' || RPAD('-', 4, '-'));

    FOR r_alum IN c_alumnos(v_cod_modulo) LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(r_alum.APENOM, 35) || r_alum.NOTA);

        IF r_alum.NOTA < 5 THEN
            v_suspensos := v_suspensos + 1;
        ELSIF r_alum.NOTA IN (5, 6) THEN
            v_aprobados := v_aprobados + 1;
        ELSIF r_alum.NOTA IN (7, 8) THEN
            v_notables := v_notables + 1;
        ELSIF r_alum.NOTA >= 9 THEN
            v_sobresalientes := v_sobresalientes + 1;
        END IF;
    END LOOP;

    -- 5. Resumen estadístico
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('RESUMEN DE CALIFICACIONES:');
    DBMS_OUTPUT.PUT_LINE('  * Suspensos:      ' || v_suspensos);
    DBMS_OUTPUT.PUT_LINE('  * Aprobados:      ' || v_aprobados);
    DBMS_OUTPUT.PUT_LINE('  * Notables:       ' || v_notables);
    DBMS_OUTPUT.PUT_LINE('  * Sobresalientes: ' || v_sobresalientes);
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------');

    -- 6. Alumnos con la nota más alta y más baja
    DBMS_OUTPUT.PUT_LINE('NOTA(S) MÁS ALTA(S) [' || v_nota_max || ']:');
    FOR r_max IN (SELECT a.APENOM FROM NOTAS n JOIN ALUMNOS a ON n.DNI = a.DNI 
                  WHERE n.COD = v_cod_modulo AND n.NOTA = v_nota_max) LOOP
        DBMS_OUTPUT.PUT_LINE('  - ' || r_max.APENOM);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('NOTA(S) MÁS BAJA(S) [' || v_nota_min || ']:');
    FOR r_min IN (SELECT a.APENOM FROM NOTAS n JOIN ALUMNOS a ON n.DNI = a.DNI 
                  WHERE n.COD = v_cod_modulo AND n.NOTA = v_nota_min) LOOP
        DBMS_OUTPUT.PUT_LINE('  - ' || r_min.APENOM);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('========================================================');

EXCEPTION
    WHEN e_tabla_alumnos_vacia THEN
        DBMS_OUTPUT.PUT_LINE('Error: La tabla ALUMNOS no contiene registros.');
    WHEN e_tabla_asignaturas_vacia THEN
        DBMS_OUTPUT.PUT_LINE('Error: La tabla ASIGNATURAS no contiene registros.');
    WHEN e_tabla_notas_vacia THEN
        DBMS_OUTPUT.PUT_LINE('Error: La tabla NOTAS no contiene registros.');
    WHEN e_modulo_no_existe THEN
        DBMS_OUTPUT.PUT_LINE('Error: El módulo "' || p_nombre_modulo || '" no existe en la base de datos.');
    WHEN e_sin_alumnos_en_modulo THEN
        DBMS_OUTPUT.PUT_LINE('Aviso: El módulo existe pero no tiene calificaciones registradas.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error imprevisto: ' || SQLERRM);
END mostrar_rendimiento_modulo;
/

SET SERVEROUTPUT ON;

-- Prueba con un módulo existente
EXECUTE mostrar_rendimiento_modulo('RET');

-- Prueba con un módulo inexistente
EXECUTE mostrar_rendimiento_modulo('Bases de Datos');