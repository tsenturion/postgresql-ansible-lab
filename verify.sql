\set ON_ERROR_STOP on
SELECT version(), current_user, current_database();
SELECT extname, extversion FROM pg_extension ORDER BY extname;
SHOW shared_preload_libraries;
SELECT octet_length(get_raw_page('pg_class', 0)) AS page_bytes;
SELECT count(*) AS buffers FROM pg_buffercache;
SELECT count(*) AS statements FROM pg_stat_statements;
SELECT * FROM dblink('dbname=postgres', 'SELECT current_user, current_database()')
  AS connection(role_name text, database_name text);
DO $python$
import io
import openpyxl
from reportlab.pdfgen import canvas
workbook = openpyxl.Workbook()
workbook.active['A1'] = 'Проверка PL/Python'
excel = io.BytesIO()
workbook.save(excel)
pdf = io.BytesIO()
document = canvas.Canvas(pdf)
document.drawString(30, 800, 'PL/Python works')
document.save()
assert len(excel.getvalue()) > 0 and len(pdf.getvalue()) > 0
plpy.notice('Excel и PDF сформированы в памяти')
$python$ LANGUAGE plpython3u;
