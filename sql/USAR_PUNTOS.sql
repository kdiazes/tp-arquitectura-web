create or replace function public.usar_puntos(
    p_id_cliente bigint,
    p_id_concepto bigint,
    p_puntos_utilizar int
)
returns json
language plpgsql
security definer
as $$
declare
    v_bolsa record;
    v_restante int := p_puntos_utilizar;
    v_utilizado int;
    v_id_uso int;
    v_result json;
begin
    -- Validar cliente y concepto
    if not exists (select 1 from cliente where id_cliente = p_id_cliente) then
        raise exception 'El cliente con ID % no existe.', p_id_cliente;
    end if;

    if not exists (select 1 from concepto_punto where id_concepto = p_id_concepto) then
        raise exception 'El concepto con ID % no existe.', p_id_concepto;
    end if;

    -- Crear cabecera del uso
    insert into uso_punto_cabecera (
        id_cliente,
        id_concepto,
        fecha,
        puntos_utilizados
    )
    values (
        p_id_cliente,
        p_id_concepto,
        current_timestamp,
        p_puntos_utilizar
    )
    returning id_uso into v_id_uso;

    -- Aplicar lógica FIFO (bolsas más antiguas primero)
    for v_bolsa in
        select * from bolsa_punto
        where id_cliente = p_id_cliente
          and saldo > 0
          and fecha_vencimiento >= current_date
        order by fecha_asignacion asc
    loop
        exit when v_restante <= 0;

        if v_bolsa.saldo >= v_restante then
            v_utilizado := v_restante;
        else
            v_utilizado := v_bolsa.saldo;
        end if;

        -- Registrar detalle del uso
        insert into uso_punto_detalle (
            id_uso,
            id_bolsa,
            puntos_utilizados
        )
        values (
            v_id_uso,
            v_bolsa.id_bolsa,
            v_utilizado
        );

        -- Actualizar saldo de la bolsa
        update bolsa_punto
        set saldo = saldo - v_utilizado,
            puntos_utilizados = puntos_utilizados + v_utilizado
        where id_bolsa = v_bolsa.id_bolsa;

        v_restante := v_restante - v_utilizado;
    end loop;

    if v_restante > 0 then
        raise exception 'El cliente no tiene puntos suficientes (% faltantes)', v_restante;
    end if;

    -- Devolver resumen del uso
    select json_build_object(
        'id_uso', v_id_uso,
        'id_cliente', p_id_cliente,
        'id_concepto', p_id_concepto,
        'puntos_usados', p_puntos_utilizar,
        'fecha', current_timestamp
    )
    into v_result;

    return v_result;
end;
$$;