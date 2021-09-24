--1. Создать структуру БД, наполнить тестовыми данными.


--1.1 Создание структур 
create table public.tb_users --клиенты
(
uid integer primary key, 
registration_date date, 
country char(50)
);

create table public.tb_logins 
(
user_uid integer, 
login char(20), 
account_type char(1) default 'D' -- D - demo, R -real,
primary key(user_uid,login)
);

create table public.billing
(
operation_type char(10), -- deposit/withdrawal
operation_date date,
login char(20), 
amount numeric(15,2)
);
commit;

CREATE TABLE public.tb_orders (
    login bpchar(20) NULL,
    order_close_date date NULL,
    amount numeric(15, 2) NULL
);

--Так же для простоты дальнейшей работы, создадим справочник городов.
Create table public.ref_cities(city_id int, city_name char(15));
commit;

insert into public.ref_cities
select 1, 'England' union
select 2, 'Spain' union
select 3, 'Ukraine' union
select 4,'Russia' union
select 5,'Canada' union
select 6,'Belorus' union
select 7,'France' union
select 8,'Portugal' union
select 9,'Argentina' union
select 10,'Brazil';
commit;


--Создание вспомогательных процедур для наполнения данными

--Функция рандома из диапазона

CREATE OR REPLACE FUNCTION public.random_between(low INT ,high INT) 
   RETURNS INT AS
$$
BEGIN
   RETURN floor(random()* (high-low + 1) + low);
END;
$$ language 'plpgsql' STRICT;



-- Функция заполнения тестовыми данными таблицы. На вход принимает к-во создаваемых клиентов

CREATE OR REPLACE FUNCTION public.test_input_data(CNT int) --параметр к-ва пользователей, которых хотим создать
 RETURNS void
 LANGUAGE plpgsql
AS $function$

declare 
--Обьявляем переменные которые будем использовать
    U_ID int;
    RAND_INT INT;
    RAND_INT_2 INT;
    CNTR varchar(20);
    RAND_CITY varchar(20);
    RAND_AMT int;
    RAND_INT_AMT int;
    ONE int;
        begin
        U_ID=1;--старт
        
            while (U_ID<CNT) --выполнять когда пока не вычитываем к-во в аргументе
            loop
                --запускаем
                RAND_CITY = (select city_name from public.ref_cities where city_id = (select public.random_between(1,10))); -- Выбираем случайный город
                RAND_INT= (select public.random_between(1,100)); -- выбираем случайное число
                RAND_INT_2= (select public.random_between(1,100)); -- выбираем еще 1 случайное число, что бы в дальнейшем правильно обыграть даты
                RAND_AMT= (select public.random_between(1,10)); -- выбираем случайное число, которое будем использовать для создания к-ва платежей
            
             insert into public.tb_users
             select U_ID, current_date - RAND_INT ,RAND_CITY; -- заполняем таблицу пользователей переменными
            --вот тут постараюсь обьяснить
            /*
            так вот, представим что у каждого 7го пользователя есть и демо и реальный счет.
            Для четкости данных, я получаю каждого седьмого пользователя, и делаю ему 2 счета, демо и реальный, для всех остальных - только реальный
            */
            if right(U_ID::varchar(5),1) = '7' 
                then  
                    --алгорим создания логина 'EX'+U_ID::varchar(5)+Тип счета
                    insert into public.tb_logins 
                    select U_ID, 'EX'||U_ID::varchar(5)||'R','R'
                    union
                    select U_ID, 'EX'||U_ID::varchar(5)||'D','D';
                else 
                    insert into public.tb_logins 
                    select U_ID, 'EX'||U_ID::varchar(5)||'R','R'; 
            end if;
        
ONE=1;          
while (ONE<RAND_AMT)--создаю разное количество платежей
loop
        --Присвоение рабочих переменных
        RAND_INT= (select public.random_between(60,90));
        RAND_INT_2= (select public.random_between(91,115));
        RAND_INT_AMT= (select public.random_between(700,1500));

insert into public.billing
select case --каждое чётное это это Депозит
        when ONE % 2 =0 then 'DEP' 
                            else 'WITHDR' 
        end, 
         (current_date - RAND_INT)+RAND_INT_2,
         'EX'||U_ID::varchar(5)||'R',
         RAND_INT_AMT;
ONE=ONE+1;--увеливаем счетчик
end loop;
--переопределяем переменные
        RAND_INT= (select public.random_between(90,100));
        RAND_INT_2= (select public.random_between(135,145));
        RAND_INT_AMT= (select public.random_between(800,900));
if right(U_ID::varchar(5),1) = '6' -- то же самое, что и выше, пусть каждый шестой пользователь имеет сделку
then insert into public.tb_orders
        select 'EX'||U_ID::varchar(5)||'R',(current_date - RAND_INT)+RAND_INT_2,RAND_INT_AMT;
    end if;

            U_ID=U_ID+1; -- увеличиваем счетчик
            end loop;
    end --конец, спасибо, что дочитали
$function$
;
commit;

--1.2 Заполнить данными
--Наполняем таблицы (10000 клиентов, для пробы)

select public.test_input_data(10000)


--Задача 2
/*
2. Написать запрос, который отобразит среднее время перехода пользователей между
этапами воронки:
- От регистрации до внесения депозита

- От внесения депозита до первой сделки на реальном счёте
Только реальные счета
Учесть, что у пользователя может быть депозит, но не быть торговых операций
Период - последние 90 дней
Группировка - по странам
Сортировка - по убыванию количества пользователей
*/
--Тут всё ясно, по хорошему конечно разнести во временные таблицы, но в задании написано "Напишите запрос", я понимаю это как всё должно быть целяком.
with agg_reg_dt as (
        select t1.Country,t2.login,t1.registration_date
        from public.tb_users as t1
        join public.tb_logins as t2 on t1.uid=t2.user_uid
        where t2.account_type = 'R'
                    ), 
        min_bill_date as (
            select login, min(operation_date) as mdt
            from public.billing 
            where operation_type ='DEP'--тип Депозит
            and right(login,1)='R'--реальный счет
            and current_date>=operation_date-90 --за 90 дней
            group by login
                        ),
        min_oper_date as (
            select login,min(order_close_date) as min_deal_dt 
            from public.tb_orders 
            where current_date>=order_close_date-90 -- операция за 90дней
            group by login
            )
select country,
    avg(diff_from_reg2dep),-- От регистрации до внесения депозита
    avg(diff_from_dep2ord),-- От внесения депозита до первой сделки на реальном счёте
    count(mdt) c, --к-во первых
    count(min_deal_dt) d --к-во вторых
from (
select  t1.Country,t1.registration_date,t1.login,t2.mdt,t3.min_deal_dt,
t2.mdt-t1.registration_date as diff_from_reg2dep,
t3.min_deal_dt-t2.mdt as diff_from_dep2ord
from agg_reg_dt as t1 
left join min_bill_date as t2 on t1.login=t2.login
left join min_oper_date as t3 on t2.login=t3.login
 ) as t1
group by country
order by c desc

----Задача 3
/*
Написать запрос, который отобразит количество всех клиентов по странам, у которых
средний депозит >=1000
Вывод: country, количество клиентов в стране, количество клиентов у которых депозит
>=1000
*/

with clients_with_dep as (
    select t1.country,count(uid) cnt_clients_with_dep
    from tb_users as t1
    join tb_logins as t2 on t1.uid=t2.user_uid
    where t2.login in (
        --в подзапросе понимаем нужных нам клиентов
        select login
        from public.billing as t1
        where operation_type = 'DEP' -- условие Депозит
        group by login
        having avg(amount) > 1000 -- средняя сумма больше 1000
    ) 
    group by t1.Country
)
--считаем, учитывая что в некоторых странах может вообще не быть необходимых нам сделок, используем кейс.
select t1.country,cnt_all_clients,case when cnt_clients_with_dep is null then 0 else cnt_clients_with_dep end
from (
    select country,count(uid) cnt_all_clients
    from public.tb_users 
    group by country
    ) as t1 
    left join clients_with_dep as t2 on t1.Country=t2.Country

--Задача 4
/*
4. Написать запрос, который выводит первые 3 депозита каждого клиента.
Вывод: uuid, login, operation_date, порядковый номер депозита
*/

--Тут обычный ранк 
with mapping_clients as (--создали маппинг для дайльнейшей работы
select t1.uid,t2.login
from public.tb_users as t1
join tb_logins as t2 on t1.uid=t2.user_uid 
where account_type='R'
)
/*
так как я не учел, что в дальнейшем нужен быть некая айди сделки, а всё уже написано, по этому использую поле ctid как порядковый номер депозита
или что тут имелось ввиду? вывести ранк?
*/
select t1.Uid,t2.login,t2.operation_date,t2.amount,t2.ctid 
from mapping_clients as t1
join (
select *, rank() OVER (partition by login ORDER BY operation_date asc),ctid
FROM public.billing as t1
where operation_type='DEP'
order by login
) as t2 on t1.login=t2.login
where rank<=3
