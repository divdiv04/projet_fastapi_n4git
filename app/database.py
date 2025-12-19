import psycopg2

def get_data():
    conn = psycopg2.connect(
        dbname="fastapi_db",
        user="fastapi_user",
        password="password",
        host="localhost"
    )
    cur = conn.cursor()
    cur.execute("SELECT 1;")
    result = cur.fetchall()
    cur.close()
    conn.close()
    return result
