-- Reproyectar 
 ALTER TABLE #Tabla_a_proyectar#
    ALTER COLUMN geom
    TYPE Geometry(#tipo_de_geometría#, #No_SRID#)
    USING ST_Transform(geom, #No_SRID#);

-- Une las dos tablas 
create table incidentes as 
select * from pgj_alvarobregon 
union 
select * from pgj_miguelhidalgo

--Crea in indice sobre la geometría
create index incidentes_zmvm_gix on incidentes using GIST(geom);

--Indentificar cuál es la columna de delitos y ver de que tipo hay
select distinct (delitos) from incidentes 

--Selecciona solo los robos de celular con y sin violencia 
where delito like 'ROBO A TRANSEUNTE DE CELULAR%'

-- Topología (Esto ya no se hace porque ya se calculó)
alter table recorte add column source integer;
alter table  recorte add column target integer;

select pgr_createTopology ('recorte', 0.01, 'geom', 'id');

--- Calcula k_means para 10 clases y calcula el centroide de los puntos

create table centroid as 
select centros.cid, st_centroid (st_collect(geom)) as geom 
from 
(SELECT ST_ClusterKMeans(geom,10) over () AS cid, 
id, geom
FROM incidentes) as centros
group by cid

-- Puntos como nodos de la red para incidentes y centroides
alter table #tabla_puntos# add column closest_node bigint; 
update #tabla_puntos# set closest_node = c.closest_node
from  
(select b.id as #id_puntos#, (
  SELECT a.id
  FROM #tabla_vertices# As a
  ORDER BY b.geom <-> a.the_geom LIMIT 1
)as closest_node
from  #tabla_puntos# b) as c
where c.#id_puntos# = #tabla_puntos#.id

-- Calcula la distancia sobre la red con un st_djkstracost y hace el join con la geometría de incidentes 

create table incidentes_centroid as 
SELECT DISTINCT ON (start_vid)
       start_vid, end_vid, agg_cost
FROM   (SELECT * FROM pgr_dijkstraCost(
    'select gid as id, source, target, long as cost from recorte',
    array(select distinct(closest_node) from incidentes),
    array(select distinct(closest_node) from centroid),
	 directed:=false)
) as sub
ORDER  BY start_vid, agg_cost asc;

--Join con la geometría
select b.geom, a.*
from incidentes_centroid a
join
(select * from incidentes ) as b
on a.start_vid = b.closest_node






