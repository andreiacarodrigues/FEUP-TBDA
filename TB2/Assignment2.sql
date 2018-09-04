------------------------------

------ Type Declaration ------

------------------------------

-- Region_t
create or replace type Region_t as object
(
    COD	NUMBER(4,0),
    DESIGNATION	VARCHAR2(50 BYTE),
    NUT1 VARCHAR2(50 BYTE)
);

-- District_t
create or replace type District_t as object
(
    COD	NUMBER(4,0),
    DESIGNATION	VARCHAR2(50 BYTE),
    REGION ref Region_t
);

-- DistrictsRef_tab_t
create or replace type DistrictsRef_tab_t as table of ref District_t;

-- Municipality
create or replace type Municipality_t as object
(
    COD	NUMBER(4,0),
    DESIGNATION	VARCHAR2(50 BYTE),
    DISTRICT ref District_t,
    REGION ref Region_t
);

-- MunicipalitiesRef_tab_t
create or replace type MunicipalitiesRef_tab_t as table of ref Municipality_t;

-- RoomType
create or replace type RoomType_t as object
(
    ROOMTYPE NUMBER(4,0),
    DESCRIPTION VARCHAR2(50 BYTE)
);

-- Facility
create or replace type Facility_t as object
(
    ID number(4,0),
    NAME varchar2(80),
    CAPACITY number(8,0),
    ROOMTYPE ref RoomType_t,
    ADDRESS varchar2(80),
    MUNICIPALITY ref Municipality_t
);

-- FacilitiesRef_tab_t
create or replace type FacilitiesRef_tab_t as table of ref Facility_t;

-- Activity
create or replace type Activity_t as object
(
    REF varchar2(20),
    ACTIVITY varchar2(20)
);

-- Activities_tab_t
create or replace type Activities_tab_t as table of Activity_t;

-- Region Districts
alter type Region_t
add attribute (DISTRICTS DistrictsRef_tab_t) CASCADE;

-- Region Municipalities
alter type Region_t
add attribute (MUNICIPALITIES MunicipalitiesRef_tab_t) CASCADE;

-- District Municipalities
alter type District_t
add attribute (MUNICIPALITIES MunicipalitiesRef_tab_t) CASCADE;

-- Municipality Facilities
alter type Municipality_t
add attribute (FACILITIES FacilitiesRef_tab_t) CASCADE;

-- Facility Activities
alter type Facility_t
add attribute (ACTIVITIES Activities_tab_t) CASCADE;

----------------------------

------ Table Creation ------

----------------------------

-- Regions
create table Regions of Region_t
    nested table Districts store as Region_Districts
    nested table Municipalities store as Region_Municipalities;

-- Districts
create table Districts of District_t
    nested table Municipalities store as District_Municipalities;

-- Municipalities
create table Municipalities of Municipality_t
    nested table Facilities store as Municipality_Facilities;

-- RoomTypes
create table RoomTypes of RoomType_t;

-- Facilities
create table Facilities of Facility_t
    nested table Activities store as Facility_Activities;

-----------------------------

------ Data Migration  ------

-----------------------------

-- Regions
delete from Regions;
insert into Regions (COD, DESIGNATION, NUT1)
select r.COD, r.DESIGNATION, r.NUT1
from gtd8.Regions r;

-- Districts
delete from Districts;
insert into Districts (COD, DESIGNATION, REGION)
select d.COD, d.DESIGNATION, (select ref(r) from Regions r where r.COD = d.REGION)
from gtd8.Districts d;

-- Municipalities
delete from Municipalities;
insert into Municipalities (COD, DESIGNATION, DISTRICT, REGION)
select m.COD, m.DESIGNATION, (select ref(d) from Districts d where d.COD = m.DISTRICT), (select ref(r) from Regions r where r.COD = m.REGION)
from gtd8.Municipalities m;

-- RoomTypes
delete from RoomTypes;
insert into RoomTypes (ROOMTYPE, DESCRIPTION)
select rt.ROOMTYPE, rt.DESCRIPTION
from gtd8.RoomTypes rt;

-- Facilities
delete from Facilities;
insert into Facilities (ID, NAME, CAPACITY, ROOMTYPE, ADDRESS, MUNICIPALITY)
select f.ID, f.NAME, f.CAPACITY, (select ref(rt) from RoomTypes rt where rt.ROOMTYPE = f.ROOMTYPE), f.ADDRESS, (select ref(m) from Municipalities m where m.COD = f.MUNICIPALITY)
from gtd8.Facilities f;

-------------------------------

------ Nested Migration  ------

-------------------------------

-- Facilities Activities
update Facilities f
set f.Activities =
cast(multiset(select a.ref, a.activity from gtd8.Activities a join gtd8.Uses u on a.ref = u.ref where u.id = f.id) as Activities_tab_t);

-- Municipalities Facilities
update Municipalities m
set m.Facilities =
cast(multiset(select ref(f) from Facilities f where m.cod = f.municipality.cod) as FacilitiesRef_tab_t);

-- Districts Municipalities
update Districts d
set d.Municipalities =
cast(multiset(select ref(m) from Municipalities m where d.cod = m.district.cod) as MunicipalitiesRef_tab_t);

-- Regions Districts
update Regions r
set r.Districts =
cast(multiset(select ref(d) from Districts d where r.cod = d.region.cod) as DistrictsRef_tab_t);

-- Regions Municipalities
update Regions r
set r.Municipalities =
cast(multiset(select ref(m) from Municipalities m where r.cod = m.region.cod) as MunicipalitiesRef_tab_t);

-----------------------------------

------ Function Declaration  ------

-----------------------------------

alter type Municipality_t
add member function GetCapacity return integer cascade;

alter type Municipality_t
add member function GetFacilityCount return integer cascade;

alter type Municipality_t
add member function GetMaxCARatio return float cascade;

alter type RoomType_t
add member function DescContains(text string) return string cascade;

alter type Facility_t
add member function CARatio return float cascade;

----------------------------------

------ Function Definition  ------

----------------------------------

create or replace type body Municipality_t as

    member function GetCapacity return integer is
    
    totalCapacity integer;
    
    begin
    
    select sum(f.capacity) into totalCapacity
    from facilities f
    where f.municipality.cod = self.cod;
    
    return totalCapacity;
    
    end GetCapacity;
    
    ---
    
    member function GetFacilityCount return integer is
    
    facilityCount integer;
    
    begin
    
    select count(*) into facilityCount
    from municipalities m, table(m.facilities) f
    where m.cod = self.cod;
    
    return facilityCount;
    
    end GetFacilityCount;
    
    --
    
    member function GetMaxCARatio return float is
    
    bestRatio float;
    
    begin
    
    select max(value(f).CARatio()) into bestRatio
    from municipalities m, table(m.facilities) f
    where m.COD = self.COD
    group by COD;
    
    return bestRatio;
    
    end GetMaxCARatio;

end;

create or replace type body RoomType_t as

    member function DescContains(text string) return string is
    
    expression varchar(50);
    
    begin
        expression := '%' || text || '%';
        
        if description like expression then
            return 'true';   
        else
            return 'false';
        end if;
        
    end DescContains;

end;

create or replace type body Facility_t as

    member function CARatio return float is
    
    activityCount integer;
    
    begin
    
    select count(*) into activityCount
    from facilities f, table(f.activities) a
    where f.ID = self.ID;
    
    if activityCount = 0 then
        return 0;
    else
        return self.CAPACITY/activityCount;
    end if;
    
    end CARatio;

end;

---------------------

------ Queries ------

---------------------

/*
a) Which are the facilities where the room type description contains 'touros' and have 'teatro' as one of their activities?
Show the id, name, description and activity.
*/

select f.id, f.name, f.roomtype.description, a.activity
from facilities f, table(f.activities) a
where
a.activity = 'teatro' and
-- f.roomtype.description like '%touros%';
f.roomtype.DescContains('touros') = 'true';

-- Showing all activities

select f.id, f.name, f.roomtype.description, a.activity
from facilities f, table(f.activities) a
where f.id
in
(
    select f.id
    from facilities f, table(f.activities) a
    where
    a.activity = 'teatro' and
    -- f.roomtype.description like '%touros%';
    f.roomtype.DescContains('touros') = 'true'
);

/*
b) How many facilities with 'touros' in the room type description are there in each region?
*/

select r.cod, r.designation, r.NUT1, Coalesce(aux.countVal, 0)
from regions r
left join
(
select r.cod, r.designation, r.NUT1, count(value(f).ID) countVal
from regions r, table(r.municipalities) m, table(value(m).facilities) f
where
-- value(f).roomtype.description like '%touros%'
value(f).roomtype.DescContains('touros') = 'true'
group by r.cod, r.designation, r.NUT1
) aux on r.cod = aux.cod
order by r.cod asc;

/*
c) How many municipalities do not have any facility with an activity of 'cinema'?
*/

select count(*)
from municipalities m
where cod not in
(
select distinct m.cod
from municipalities m, table(m.facilities) f, table(value(f).activities) a
where a.activity = 'cinema'
);

/*
d) Which is the municipality with more facilities engaged in each of the six kinds of activities?
Show the activity, the municipality name and the corresponding number of facilities.
*/

-- Greatest n per group problem

-- Solution 1, Join with Group-Identifier Max-value-in-Group Subquery

select t1.*
from
(
    select a.ACTIVITY, m.COD, m.DESIGNATION, count(value(f).ID) CountValue
    from municipalities m, table(m.facilities) f, table(value(f).activities) a
    group by a.ACTIVITY, m.COD, m.DESIGNATION
) t1
inner join
(
    select ACTIVITY, max(CountValue) MaxCountValue
    from
    (
        select a.ACTIVITY, m.COD, count(value(f).ID) CountValue
        from municipalities m, table(m.facilities) f, table(value(f).activities) a
        group by a.ACTIVITY, m.COD
    )
    group by ACTIVITY
) t2 on t1.ACTIVITY = t2.ACTIVITY and t1.CountValue = t2.MaxCountValue
order by t1.ACTIVITY;

-- Solution 2, Left Join Self using join conditions

select t1.*
from
(
    select a.ACTIVITY, m.COD, m.DESIGNATION, count(value(f).ID) CountValue
    from municipalities m, table(m.facilities) f, table(value(f).activities) a
    group by a.ACTIVITY, m.COD, m.DESIGNATION
)
t1
left outer join
(
    select a.ACTIVITY, m.COD, m.DESIGNATION, count(value(f).ID) CountValue
    from municipalities m, table(m.facilities) f, table(value(f).activities) a
    group by a.ACTIVITY, m.COD, m.DESIGNATION
)
t2 ON (t1.ACTIVITY = t2.ACTIVITY AND t1.CountValue < t2.CountValue)
WHERE t2.ACTIVITY IS NULL
ORDER BY t1.ACTIVITY;

-- Base Table
select a.ACTIVITY, m.COD, count(value(f).ID) CountValue
from municipalities m, table(m.facilities) f, table(value(f).activities) a
group by a.ACTIVITY, m.COD;

/*
e) Which are the codes and designations of the districts with facilities in all the
municipalities?
*/

-- Without using methods

select d.COD, d.DESIGNATION
from districts d
where d.COD not in
    (
    select distinct d.COD
    from districts d, table(d.municipalities) m
    where (d.DESIGNATION, value(m).DESIGNATION) not in
    (
        select d.DESIGNATION, value(m).DESIGNATION
        from districts d, table(d.municipalities) m, table(value(m).facilities) f
    )
)
order by COD;

-- Using methods (faster)

select d.COD, d.DESIGNATION
from districts d
where d.COD not in
(
    select distinct d.COD
    from districts d, table(d.municipalities) m
    where value(m).GetFacilityCount() = 0
)
order by COD;

/*
f)  What is the total capacity of each Municipality? (sum of the capacity of all facilities in that municipality)
Show the municipality code, name and total capacity
*/

select m.COD, m.DESIGNATION, Coalesce(m.GetCapacity(), 0) TotalCapacity
from municipalities m
order by TotalCapacity desc;

/*
g) In each municipality, what is the facility with the best capacity/activity ratio, 2 decimals
*/

select m.COD, value(f).ID, round(value(f).CARatio(), 2) MaxCARatio
from municipalities m, table(m.facilities) f
where value(f).CARatio() = m.GetMaxCARatio()
order by m.COD;