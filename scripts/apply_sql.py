#!/usr/bin/env python3
"""
Aplica arquivos .sql no banco apontado por DATABASE_URL, usando psycopg2.
Assim não é preciso ter o cliente `psql` instalado (útil no GitHub Actions e
para aplicar o schema no Supabase sem instalar nada localmente).

Uso:
  export DATABASE_URL="postgresql://.../postgres?sslmode=require"
  python scripts/apply_sql.py db/schema.sql db/views_agreement.sql
"""

import os
import sys

import psycopg2


def main(paths):
    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        sys.exit("ERRO: defina DATABASE_URL.")
    if not paths:
        sys.exit("Uso: python scripts/apply_sql.py arquivo1.sql [arquivo2.sql ...]")

    conn = psycopg2.connect(dsn)
    conn.autocommit = True          # deixa BEGIN/COMMIT dos próprios arquivos mandarem
    try:
        with conn.cursor() as cur:
            for path in paths:
                sql = open(path, encoding="utf-8").read()
                print(f"aplicando {path} ...")
                cur.execute(sql)
        print("OK — SQL aplicado.")
    finally:
        conn.close()


if __name__ == "__main__":
    main(sys.argv[1:])
