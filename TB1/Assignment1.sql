/*

SET TIMING ON;
SET AUTOTRACE TRACE EXPLAIN;
SET AUTOTRACE ON EXPLAIN;

*/

/*

QUESTION 1

Seleção e junção.

Qual a lista dos números dos alunos especiais, que terminaram o curso com sigla EIC em menos de cinco anos, e quantos anos demoraram.

*/

-- CREATE BITMAP INDEX IDX_ZALUS_ESTADO_TEMPOCURSO ON ZALUS (ESTADO, A_LECT_CONCLUSAO - A_LECT_MATRICULA);

SET TIMING ON;
SET AUTOTRACE TRACE EXPLAIN;
SET AUTOTRACE ON EXPLAIN;

SELECT alu.numero AS Aluno, (alu.a_lect_conclusao - alu.a_lect_matricula) AS Anos
FROM ZALUS alu
JOIN ZLICS lics ON alu.curso = lics.codigo
WHERE lics.sigla =  'EIC'
AND alu.estado = 'C'
AND (alu.a_lect_conclusao - alu.a_lect_matricula) < 5
;

/*

QUESTION 2

Agregação.

Qual a média mínima de candidatura em cada curso, em cada ano, dos alunos matriculados? Nem todas as candidaturas têm a média preenchida.

*/

-- CREATE INDEX IDX_ZALUS_CURSO_MATRICULA_BI ON ZALUS (CURSO, A_LECT_MATRICULA, BI);

SET TIMING ON;
SET AUTOTRACE TRACE EXPLAIN;
SET AUTOTRACE ON EXPLAIN;

SELECT cand.CURSO, cand.ANO_LECTIVO, MIN(cand.MEDIA) MEDIA_MIN
FROM ZALUS alu
JOIN ZCANDS cand ON cand.BI = alu.BI AND cand.ANO_LECTIVO = alu.A_LECT_MATRICULA AND cand.CURSO = alu.CURSO
WHERE
cand.MEDIA IS NOT NULL
GROUP BY cand.CURSO, cand.ANO_LECTIVO
;

/*

QUESTION 3

Considere a questão de saber quantos candidatos aceites não se matricularam nesse ano lectivo.
Compare uma formulação que use uma subpergunta constante com a equivalente que use uma subpergunta variável (sugestão: usar EXISTS).

*/

-- Varying Solution

-- CREATE INDEX IDX_ZALUS_CURSO_MATRICULA_BI ON ZALUS (CURSO, A_LECT_MATRICULA, BI);

SET TIMING ON;
SET AUTOTRACE TRACE EXPLAIN;
SET AUTOTRACE ON EXPLAIN;

SELECT COUNT(*) AS NAO_MATRICULADOS
FROM ZCANDS cand
WHERE
cand.RESULTADO = 'C' AND
NOT EXISTS
(
    SELECT alu.BI
    FROM ZALUS alu
    WHERE
    alu.A_LECT_MATRICULA = cand.ANO_LECTIVO AND
    alu.BI = cand.BI AND
    alu.CURSO = cand.CURSO
)
;

-- Constant Solution

-- CREATE INDEX IDX_ZALUS_CURSO_MATRICULA_BI ON ZALUS (CURSO, A_LECT_MATRICULA, BI);

SET TIMING ON;
SET AUTOTRACE TRACE EXPLAIN;
SET AUTOTRACE ON EXPLAIN;

SELECT COUNT(*) NAO_MATRICULADOS
FROM ZCANDS cand
WHERE resultado='C' AND
(BI, ano_lectivo, curso) NOT IN
(
SELECT alu.BI, alu.a_lect_matricula, alu.curso
FROM ZALUS alu
);

/*

QUESTION 4

Estude as tentativas de resposta à questão "Qual o curso com a melhor média de conclusão em cada ano lectivo".
Comente-as.

*/

-- Greatest n per group problem

-- Solution 1, Join with Group-Identifier Max-value-in-Group Subquery

SET TIMING ON;
SET AUTOTRACE TRACE EXPLAIN;
SET AUTOTRACE ON EXPLAIN;

SELECT t1.*
FROM
(
SELECT A_LECT_CONCLUSAO, CURSO, AVG_MED_FINAL
FROM
(
SELECT alu.A_LECT_CONCLUSAO, alu.CURSO, AVG(alu.MED_FINAL) AVG_MED_FINAL
FROM ZALUS alu
WHERE alu.MED_FINAL IS NOT NULL
GROUP BY alu.A_LECT_CONCLUSAO, alu.CURSO
)
) t1
INNER JOIN
(
SELECT A_LECT_CONCLUSAO, MAX(AVG_MED_FINAL) MAX_AVG_MEDIA_FINAL
FROM
(
SELECT A_LECT_CONCLUSAO, CURSO, AVG_MED_FINAL
FROM
(
SELECT alu.A_LECT_CONCLUSAO, alu.CURSO, AVG(alu.MED_FINAL) AVG_MED_FINAL
FROM ZALUS alu
WHERE alu.MED_FINAL IS NOT NULL
GROUP BY alu.A_LECT_CONCLUSAO, alu.CURSO
ORDER BY alu.A_LECT_CONCLUSAO, alu.CURSO
)
)
GROUP BY A_LECT_CONCLUSAO
) t2 ON t1.A_LECT_CONCLUSAO = t2.A_LECT_CONCLUSAO AND t1.AVG_MED_FINAL = t2.MAX_AVG_MEDIA_FINAL
ORDER BY t1.A_LECT_CONCLUSAO
;

-- Solution 2, Left Join Self using join conditions

SELECT t1.*
FROM
(
SELECT A_LECT_CONCLUSAO, CURSO, AVG_MED_FINAL
FROM
(
SELECT alu.A_LECT_CONCLUSAO, alu.CURSO, AVG(alu.MED_FINAL) AVG_MED_FINAL
FROM ZALUS alu
WHERE alu.MED_FINAL IS NOT NULL
GROUP BY alu.A_LECT_CONCLUSAO, alu.CURSO
ORDER BY alu.A_LECT_CONCLUSAO, alu.CURSO
)
)
t1
LEFT OUTER JOIN
(
SELECT A_LECT_CONCLUSAO, CURSO, AVG_MED_FINAL
FROM
(
SELECT alu.A_LECT_CONCLUSAO, alu.CURSO, AVG(alu.MED_FINAL) AVG_MED_FINAL
FROM ZALUS alu
WHERE alu.MED_FINAL IS NOT NULL
GROUP BY alu.A_LECT_CONCLUSAO, alu.CURSO
ORDER BY alu.A_LECT_CONCLUSAO, alu.CURSO
)
)
t2 ON (t1.A_LECT_CONCLUSAO = t2.A_LECT_CONCLUSAO AND t1.AVG_MED_FINAL < t2.AVG_MED_FINAL)
WHERE t2.A_LECT_CONCLUSAO IS NULL
ORDER BY t1.A_LECT_CONCLUSAO
;

-- Base Table

SELECT A_LECT_CONCLUSAO, CURSO, AVG_MED_FINAL
FROM
(
SELECT alu.A_LECT_CONCLUSAO, alu.CURSO, AVG(alu.MED_FINAL) AVG_MED_FINAL
FROM XALUS alu
WHERE alu.MED_FINAL IS NOT NULL
GROUP BY alu.A_LECT_CONCLUSAO, alu.CURSO
ORDER BY alu.A_LECT_CONCLUSAO, alu.CURSO
)
;

/*

QUESTION 5

Compare os planos de execução da pesquisa "Quantos candidatos tiveram como resultado algo diferente de 'C' ou 'E'", usando, no contexto Z,
a. Com índice árvore-B em Resultado;
b. Com índice bitmap em Resultado

*/

-- CREATE BITMAP INDEX IDX_ZCANDS_RESULTADO ON ZCANDS (RESULTADO);

SET TIMING ON;
SET AUTOTRACE TRACE EXPLAIN;
SET AUTOTRACE ON EXPLAIN;

SELECT count(*) candidatos
FROM ZCANDS cand
WHERE cand.RESULTADO != 'C' AND cand.RESULTADO != 'E'
;

/*

QUESTION 6

A pergunta
"Há, em algum ano algum curso (ano_lectivo, sigla e nome) que tenha todas as candidaturas aceites transformadas em matrículas, nesse mesmo ano?",
é de natureza universal.
Compare do ponto de vista temporal e de plano de execução as estratégias da dupla negação e da contagem.

Ano_lectivo, sigla e nome dos cursos que tenham todas as candidaturas aceites transformadas em matrículas, nesse mesmo ano.

Double negation:
Em cada ano dá-me todos os cursos onde não há candidaturas onde não há licenciaturas

*/

-- Double Negation

SET TIMING ON;
SET AUTOTRACE TRACE EXPLAIN;
SET AUTOTRACE ON EXPLAIN;

-- CREATE INDEX IDX_ZALUS_CURSO_MATRICULA_BI ON ZALUS (CURSO, A_LECT_MATRICULA, BI);

SELECT cand.ANO_LECTIVO, cand.CURSO, lics.SIGLA, lics.NOME
FROM ZCANDS cand
JOIN ZLICS lics ON lics.CODIGO = cand.CURSO
WHERE cand.RESULTADO = 'C' AND
(ANO_LECTIVO, CURSO) NOT IN
(
SELECT cand.ANO_LECTIVO, cand.CURSO
FROM ZCANDS cand
WHERE cand.RESULTADO = 'C' AND
NOT EXISTS
(
    SELECT *
    FROM ZALUS alu
    WHERE alu.A_LECT_MATRICULA = cand.ANO_LECTIVO AND
    alu.BI = cand.BI AND
    alu.CURSO = cand.CURSO
)
GROUP BY cand.ANO_LECTIVO, cand.CURSO
)
GROUP BY cand.ANO_LECTIVO, cand.CURSO, lics.SIGLA, lics.NOME
;

-- Count

SET TIMING ON;
SET AUTOTRACE TRACE EXPLAIN;
SET AUTOTRACE ON EXPLAIN;

-- CREATE INDEX IDX_ZALUS_CURSO_MATRICULA_BI ON ZALUS (CURSO, A_LECT_MATRICULA, BI);

SELECT cands.ANO_LECTIVO, cands.CURSO, lics.SIGLA, lics.NOME
FROM
(
SELECT cands.ANO_LECTIVO, cands.CURSO, count(*) CANDIDATURAS
FROM ZCANDS cands
WHERE cands.RESULTADO = 'C'
GROUP BY cands.ANO_LECTIVO, cands.CURSO
) cands
JOIN
(
SELECT A_LECT_MATRICULA, CURSO, MATRICULAS
FROM
(
SELECT alu.A_LECT_MATRICULA, alu.CURSO, count(*) MATRICULAS
FROM ZALUS alu
GROUP BY alu.A_LECT_MATRICULA, alu.CURSO
)
) alu ON alu.A_LECT_MATRICULA = cands.ANO_LECTIVO AND alu.CURSO = cands.CURSO
JOIN ZLICS lics ON lics.CODIGO = cands.CURSO
WHERE
CANDIDATURAS = MATRICULAS
;

/*

---------- TESTING ----------

*/

SELECT cand.BI, cand.ANO_LECTIVO
FROM XCANDS cand
WHERE
cand.RESULTADO = 'C' AND
NOT EXISTS
(
    SELECT 1
    FROM XALUS alu
    WHERE alu.A_LECT_MATRICULA = cand.ANO_LECTIVO
)       and alu.bi = cand.bi
;

SELECT cand.ANO_LECTIVO ano, COUNT(*) AS NAO_MATRICULADOS
FROM XCANDS cand
FULL JOIN XALUS alu ON cand.BI = alu.BI AND cand.ANO_LECTIVO = alu.A_LECT_MATRICULA
where cand.resultado = 'C' AND alu.BI IS NULL 
GROUP BY cand.ANO_LECTIVO
ORDER BY cand.ANO_LECTIVO
;

-- QUESTION 6

-- ANOS E CURSOS COM CANDIDATURAS SEM MATRICULA

SELECT cand.ANO_LECTIVO, cand.CURSO
FROM XCANDS cand
WHERE cand.RESULTADO = 'C' AND
NOT EXISTS
(
    SELECT *
    FROM XALUS alu
    WHERE alu.A_LECT_MATRICULA = cand.ANO_LECTIVO AND
    alu.BI = cand.BI AND
    alu.CURSO = cand.CURSO
)
GROUP BY cand.ANO_LECTIVO, cand.CURSO
;

-- OLD QUESTION 4 VARYING

SELECT cand.ANO_LECTIVO ano, COUNT(*) AS NAO_MATRICULADOS
FROM XCANDS cand
WHERE
cand.RESULTADO = 'C' AND
NOT EXISTS
(
    SELECT alu.BI
    FROM XALUS alu
    WHERE
    alu.A_LECT_MATRICULA = cand.ANO_LECTIVO AND
    alu.BI = cand.BI AND
    alu.CURSO = cand.CURSO
)
GROUP BY cand.ANO_LECTIVO
ORDER BY cand.ANO_LECTIVO
;

-- OLD QUESTION 4 CONSTANT

SELECT ANO_LECTIVO, NAO_MATRICULADOS - NVL(MATRICULADOS, 0) as RESULTADO
FROM
(
SELECT ANO_LECTIVO, COUNT(*) NAO_MATRICULADOS, MATRICULADOS
FROM XCANDS cand
LEFT JOIN
(
SELECT alu.A_LECT_MATRICULA, Count(*) AS MATRICULADOS
FROM XALUS alu
GROUP BY alu.A_LECT_MATRICULA
) ON ANO_LECTIVO = A_LECT_MATRICULA
WHERE
cand.RESULTADO = 'C'
GROUP BY ANO_LECTIVO, MATRICULADOS
) TEMP
WHERE (NAO_MATRICULADOS - NVL(MATRICULADOS, 0) > 0)
ORDER BY ANO_LECTIVO
;

---

SELECT alu.numero AS Aluno, (alu.a_lect_conclusao - alu.a_lect_matricula) AS Anos
FROM ZALUS alu
JOIN ZLICS lics ON alu.curso = lics.codigo
WHERE lics.sigla =  'EIC'
AND alu.estado = 'C'
AND (alu.a_lect_conclusao - alu.a_lect_matricula) < 5
;
