CREATE TABLE public.cliente (
  id_cliente bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  nombre character varying NOT NULL,
  apellido character varying NOT NULL,
  nro_documento character varying NOT NULL UNIQUE,
  email character varying,
  telefono character varying,
  tipo_documento character varying,
  nacionalidad character varying,
  fecha_nacimiento date,
  fecha_alta timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT cliente_pkey PRIMARY KEY (id_cliente)
);

CREATE TABLE public.concepto_punto (
  id_concepto bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  descripcion character varying NOT NULL,
  puntos_requeridos integer NOT NULL CHECK (puntos_requeridos > 0),
  estado boolean NOT NULL DEFAULT true,
  CONSTRAINT concepto_punto_pkey PRIMARY KEY (id_concepto)
);

CREATE TABLE public.regla_punto (
  id_regla bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  descripcion character varying,
  desde_gs numeric,
  hasta_gs numeric,
  cada_gs numeric NOT NULL CHECK (cada_gs > 0::numeric),
  otorga_pts integer NOT NULL CHECK (otorga_pts > 0),
  estado boolean NOT NULL DEFAULT true,
  CONSTRAINT regla_punto_pkey PRIMARY KEY (id_regla)
);

CREATE TABLE public.vencimiento_punto (
  id_vencimiento bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  fecha_inicio date NOT NULL,
  fecha_fin date NOT NULL,
  validez_dias integer CHECK (validez_dias IS NULL OR validez_dias >= 0),
  estado boolean NOT NULL DEFAULT true,
  CONSTRAINT vencimiento_punto_pkey PRIMARY KEY (id_vencimiento)
);

CREATE TABLE public.bolsa_punto (
  id_bolsa bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  id_cliente bigint NOT NULL,
  fecha_asignacion timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_vencimiento date,
  movimiento character varying,
  observacion character varying,
  puntos_asignados integer NOT NULL CHECK (puntos_asignados > 0),
  puntos_utilizados integer NOT NULL DEFAULT 0 CHECK (puntos_utilizados >= 0),
  saldo integer,
  monto_operacion_gs numeric,
  id_vencimiento integer,
  id_regla integer,
  CONSTRAINT bolsa_punto_pkey PRIMARY KEY (id_bolsa),
  CONSTRAINT bolsa_punto_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cliente(id_cliente),
  CONSTRAINT fk_bolsa_vencimiento FOREIGN KEY (id_vencimiento) REFERENCES public.vencimiento_punto(id_vencimiento),
  CONSTRAINT fk_bolsa_regla FOREIGN KEY (id_regla) REFERENCES public.regla_punto(id_regla)
);

CREATE TABLE public.uso_punto_cabecera (
  id_uso bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  id_cliente bigint NOT NULL,
  id_concepto bigint NOT NULL,
  fecha timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  puntos_utilizados integer NOT NULL CHECK (puntos_utilizados > 0),
  CONSTRAINT uso_punto_cabecera_pkey PRIMARY KEY (id_uso),
  CONSTRAINT uso_punto_cabecera_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cliente(id_cliente),
  CONSTRAINT uso_punto_cabecera_id_concepto_fkey FOREIGN KEY (id_concepto) REFERENCES public.concepto_punto(id_concepto)
);

CREATE TABLE public.uso_punto_detalle (
  id_detalle bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  id_uso bigint NOT NULL,
  id_bolsa bigint NOT NULL,
  puntos_utilizados integer NOT NULL CHECK (puntos_utilizados > 0),
  CONSTRAINT uso_punto_detalle_pkey PRIMARY KEY (id_detalle),
  CONSTRAINT uso_punto_detalle_id_uso_fkey FOREIGN KEY (id_uso) REFERENCES public.uso_punto_cabecera(id_uso),
  CONSTRAINT uso_punto_detalle_id_bolsa_fkey FOREIGN KEY (id_bolsa) REFERENCES public.bolsa_punto(id_bolsa)
);
