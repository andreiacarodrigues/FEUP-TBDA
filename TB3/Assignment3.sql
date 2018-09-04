/* ---------- ORACLE ---------- */

/*

QUESTION 1

How many class hours of each type did the program 233 got in year 2004/2005?

*/

select t.tipo, sum(t.turnos * t.horas_turno) previsto
from XTIPOSAULA t
natural join XUCS u
where u.curso=233
and t.ano_letivo = '2004/2005'
group by t.tipo
order by t.tipo;

/*

QUESTION 2

Which courses (show the code, total class hours required, total classes
assigned) have a difference between total class hours required and the service
actually assigned in year 2003/2004?

*/

select codigo, sum(turnos * horas_turno) requeridas , sum(horas) servico
from XTIPOSAULA natural join XUCS natural join XDSD
where ano_letivo='2003/2004'
group by codigo
having sum(turnos * horas_turno) <> sum(horas)
order by codigo;

/*

QUESTION 3

Who is the professor with more class hours for each type of class, in the
academic year 2003/2004? Show the number and name of the professor, the
type of class and the total of class hours times the factor.

*/
SELECT t1.*
FROM
(
    select t.tipo, d.nome, sum(dsd.horas) horas
    from xdocentes d
    natural join xdsd dsd
    natural join xtiposaula t
    where ano_letivo='2003/2004'
    group by t.tipo, d.nome
) t1
INNER JOIN
(
    select tipo, max(horas) max_horas
    from
    (
        select t.tipo, d.nome, sum(dsd.horas) horas
        from xdocentes d
        natural join xdsd dsd
        natural join xtiposaula t
        where ano_letivo='2003/2004'
        group by t.tipo, d.nome
        order by d.nome
    )
    group by tipo
) t2 ON t1.tipo = t2.tipo AND t1.horas = t2.max_horas
ORDER BY t1.tipo;

-- Base Table
select t.tipo, d.nome, sum(dsd.horas)
from xdocentes d
natural join xdsd dsd
natural join xtiposaula t
where ano_letivo='2003/2004'
group by t.tipo, d.nome
order by t.tipo, d.nome;

/*

QUESTION 4

Which is the average number of hours by professor by year in each category,
in the years between 2001/2002 and 2004/2005?

Para cada cada categoria, nos anos referidos, calcular a média de horas por professor por ano.

*/

select categoria, round(avg(horas),2) avg_horas
from
(
    select d.categoria, d.nome, avg(dsd.horas) horas
    from xdocentes d
    natural join xdsd dsd
    natural join xtiposaula t
    where t.ano_letivo >= '2001/2002' and t.ano_letivo <= '2004/2005'
    group by d.categoria, d.nome
)
group by categoria
order by categoria;

/*

QUESTION 5

Which is the total hours per week, on each semester, that an hypothetical
student enrolled in every course of a single curricular year from each program
would get.

Qual o número de horas por semestre dos estudantes de cada ano de cada curso.

*/

select t.ano_letivo, u.curso, coalesce((sum(turnos * horas_turno) / 2), 0) horas_semestre
from xtiposaula t
natural join xucs u
group by t.ano_letivo, u.curso
order by t.ano_letivo, u.curso;

/*

QUESTION 6

How many students failed with frequency in each uc each year?
Show the code, initials, year and number of students who failed with frequency.

*/

select u.codigo, u.sigla_uc, o.ano_letivo, (o.com_frequencia - o.aprovados) reprovados_com_frequencia
from xucs u
join xocorrencias o on u.codigo = o.codigo
where (o.com_frequencia - o.aprovados) > 0;

/* ---------- MONGO ---------- */

/* Aux Function */

create or replace procedure print_clob( p_clob in clob )as l_offset number default 1;
begin
    loop exit when l_offset > dbms_lob.getlength(p_clob);
    
        dbms_output.put_line( dbms_lob.substr( p_clob, 32000, l_offset ) );
        l_offset := l_offset + 32000;
       
    end loop;
end;

/* Export UCs */

CREATE OR REPLACE procedure export_ucs IS
 
v_sqlselect VARCHAR2(4000);
v_queryctx DBMS_XMLQuery.ctxType;
v_clob_par CLOB;
 
l_offset number default 1;
 
BEGIN
 
v_sqlselect :=
'
select u.codigo, u.designacao, u.sigla_uc, u.curso, CURSOR
(
	select o.ano_letivo, o.periodo, o.inscritos, o.com_frequencia, o.aprovados, o.departamento, CURSOR
	(
		select t.id, t.tipo, t.turnos, t.n_aulas, t.horas_turno, CURSOR
		(
			select dsd.nr, dsd.horas, dsd.fator, dsd.ordem
			from gtd10.xdsd dsd
			where dsd.id = t.id
		) as distribuicao
		from gtd10.xtiposaula t
		where t.codigo = o.codigo and t.ano_letivo = o.ano_letivo and t.periodo = o.periodo) as tiposaula
	from gtd10.xocorrencias o where o.codigo = u.codigo) as requisicoes
from gtd10.xucs u
';

v_queryctx := DBMS_XMLQuery.newContext(v_sqlselect);
 
DBMS_XMLQuery.setEncodingTag(v_queryctx, 'ISO-8859-1');
DBMS_XMLQuery.setRowSetTag(v_queryctx,UPPER('UCS'));
DBMS_XMLQuery.setRowTag(v_queryctx, UPPER('UC'));
 
v_clob_par := DBMS_XMLQuery.getXML(v_queryctx);
DBMS_XMLQuery.closeContext(v_queryctx);
print_clob(v_clob_par);

END;

/* Execute export UCs */

execute export_ucs;

/* Export Docentes */

CREATE OR REPLACE procedure export_docentes IS
 
v_sqlselect VARCHAR2(4000);
v_queryctx DBMS_XMLQuery.ctxType;
v_clob_par CLOB;
 
l_offset number default 1;
 
BEGIN
 
v_sqlselect :=
'
select d.nr, d.sigla, d.categoria, d.proprio, d.apelido, d.estado, CURSOR(
    select dsd.id, dsd.horas, dsd.fator, dsd.ordem
    from gtd10.xdsd dsd
    where dsd.nr = d.nr
) as distribuicao
from gtd10.xdocentes d
';

v_queryctx := DBMS_XMLQuery.newContext(v_sqlselect);
 
DBMS_XMLQuery.setEncodingTag(v_queryctx, 'ISO-8859-1');
DBMS_XMLQuery.setRowSetTag(v_queryctx,UPPER('DOCENTES'));
DBMS_XMLQuery.setRowTag(v_queryctx, UPPER('DOCENTE'));
 
v_clob_par := DBMS_XMLQuery.getXML(v_queryctx);
DBMS_XMLQuery.closeContext(v_queryctx);
print_clob(v_clob_par);

END;

/* Execute export Docentes */

execute export_docentes;