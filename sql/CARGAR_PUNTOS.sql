create or replace function public.cargar_puntos(
    p_id_cliente bigint,
    p_monto numeric
)
returns json
language plpgsql
security definer
as $$
declare
    v_regla record;
    v_venc record;
    v_puntos int;
    v_id_bolsa int;
    v_result json;
begin
    -- Validar cliente existente
    if not exists (select 1 from cliente where id_cliente = p_id_cliente) then
        raise exception 'El cliente con ID % no existe.', p_id_cliente;
    end if;

    -- Buscar regla aplicable
    select * into v_regla
    from regla_punto
    where estado = true
      and (
        (p_monto between coalesce(desde_gs,0) and coalesce(hasta_gs,p_monto))
        or (hasta_gs is null and p_monto >= desde_gs)
      )
    order by desde_gs asc
    limit 1;

    if not found then
        raise exception 'No se encontró una regla válida para el monto %', p_monto;
    end if;

    -- Calcular puntos
    v_puntos := floor(p_monto / v_regla.cada_gs) * v_regla.otorga_pts;

    -- Obtener vencimiento activo
    select * into v_venc
    from vencimiento_punto
    where estado = true
    order by fecha_inicio desc
    limit 1;

    if not found then
        raise exception 'No se encontró un vencimiento activo';
    end if;

    -- Insertar en bolsa de puntos con referencias FK
    insert into bolsa_punto (
        id_cliente,
        id_regla,
        id_vencimiento,
        fecha_asignacion,
        fecha_vencimiento,
        movimiento,
        observacion,
        puntos_asignados,
        puntos_utilizados,
        monto_operacion_gs,
		saldo
    )
    values (
        p_id_cliente,
        v_regla.id_regla,
        v_venc.id_vencimiento,
        current_date,
        v_venc.fecha_fin,
        'Asignación de puntos',
        'Carga automática por operación',
        v_puntos,
        0,
        p_monto,
		v_puntos
    )
    returning id_bolsa into v_id_bolsa;

    -- Devolver JSON de resultado
    select json_build_object(
        'id_bolsa', v_id_bolsa,
        'id_cliente', p_id_cliente,
        'id_regla', v_regla.id_regla,
        'id_vencimiento', v_venc.id_vencimiento,
        'puntos_asignados', v_puntos,
        'fecha_vencimiento', v_venc.fecha_fin
    )
    into v_result;

    return v_result;
end;

$$;