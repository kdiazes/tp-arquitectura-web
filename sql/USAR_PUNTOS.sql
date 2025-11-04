CREATE OR REPLACE FUNCTION public.usar_puntos(
    p_id_cliente bigint,
    p_id_concepto bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
    v_bolsa record;
    v_puntos_requeridos int; -- <--- NUEVA VARIABLE
    v_restante int;
    v_utilizado int;
    v_id_uso int;
    v_result json;
begin
    -- Validar cliente
    if not exists (select 1 from cliente where id_cliente = p_id_cliente) then
        raise exception 'El cliente con ID % no existe.', p_id_cliente;
    end if;

    -- Validar concepto Y OBTENER PUNTOS REQUERIDOS
    select puntos_requeridos into v_puntos_requeridos
    from concepto_punto
    where id_concepto = p_id_concepto
      and estado = true;

    if not found then
        raise exception 'El concepto con ID % no existe o está inactivo.', p_id_concepto;
    end if;

    -- Asignar puntos requeridos a la variable restante
    v_restante := v_puntos_requeridos;

    -- Crear cabecera del uso (ahora usa la variable consultada)
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
        v_puntos_requeridos -- <--- CAMBIO
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

    -- Si v_restante > 0, el cliente no tenía saldo suficiente
    if v_restante > 0 then
        -- (Importante: ¡Esto cancela toda la transacción!)
        raise exception 'El cliente no tiene puntos suficientes (% faltantes)', v_restante;
    end if;

    -- Devolver resumen del uso
    select json_build_object(
        'id_uso', v_id_uso,
        'id_cliente', p_id_cliente,
        'id_concepto', p_id_concepto,
        'puntos_usados', v_puntos_requeridos, -- <--- CAMBIO
        'fecha', current_timestamp
    )
    into v_result;

    return v_result;
end;
$$;