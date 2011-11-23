-- entities
create table entities (
    id		char(32) not null default '',
-- entity type
    etype	char(32) not null default '',
-- time of last modification of the entity
    modtime	int(4) not null default 0
);

create index entities_id_idx on entities(id);
create index entities_etype_idx on entities(etype);

-- entities' attributes
create table attributes (
-- entity id
    entity	char(32) not null default '',
-- name of entity's attribute
    name	char(32) not null default '',
-- value of entity's attribute
    val		text not null default ''
);

create index attributes_entity_idx on attributes(entity);
