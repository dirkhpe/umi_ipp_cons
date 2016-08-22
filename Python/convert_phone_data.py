"""
Convert Phone Data - The Python way.
Goal is to convert Perl Script into Python. This should allow then to create a self-contained exe from the Python
script. Using pp to convert Perl into a self-contained exe didn't work that well.
"""

import csv
import logging
import os
import pypyodbc
import sys
from lib import my_env


def init_env(projectname):
    projectname = projectname
    modulename = my_env.get_modulename(__file__)
    config = my_env.get_inifile(projectname, __file__)
    my_log = my_env.init_loghandler(config, modulename)
    my_log.info('Start Application')
    return config


def process_record(rec, db_cur):
    columns = ', '.join(rec.keys())
    qmarks = ', '.join('?' * len(rec))
    qry = "Insert Into ipphones_int ({}) Values ({})".format(columns, qmarks)
    try:
        db_cur.execute(qry, list(rec.values()))
    except:
        e = sys.exc_info()[1]
        ec = sys.exc_info()[0]
        logmsg = "Error Class: %s, Message: %s"
        logging.critical(logmsg, ec, e)
        sys.exit()
    db_cur.commit()
    return


def process_extract(file_name, db_cur):
    logmsg = "Filename: %s"
    logging.info(logmsg, file_name)
    # with open(file_name, encoding="ISO-8859-1") as csvfile:
    with open(file_name, encoding="utf-8") as csvfile:
        reader = csv.DictReader(csvfile, delimiter=',')
        rec = {}
        for row in reader:
            rec["Device_Name"] = row["Device Name"]
            rec["Description"] = row["Description"]
            rec["Device_Pool"] = row["Device Pool"]
            rec["Location"] = row["Location"]
            rec["Device_Type"] = row["Device Type"]
            rec["Directory_Number_1"] = row["Directory Number 1"]
            # Remove leading / from phone number
            try:
                if rec["Directory_Number_1"][0] == "\\":
                    rec["Directory_Number_1"] = row["Directory Number 1"][1:]
            except (IndexError, TypeError):
                pass
            rec["Line_Text_Label_1"] = row["Line Text Label 1"]
            rec["User_ID_1"] = row["User ID 1"]
            logging.debug(rec)
            process_record(rec, db_cur)
    return


def connect_db(config):
    db_path = config['db']['path']
    conn_str = 'driver=Microsoft Access Driver (*.mdb, *.accdb);dbq=' + db_path
    logging.debug("Connection String: %s", conn_str)
    try:
        db_conn = pypyodbc.connect(conn_str)
    except:
        e = sys.exc_info()[1]
        ec = sys.exc_info()[0]
        logmsg = "Error Class: %s, Message: %s"
        logging.critical(logmsg, ec, e)
        sys.exit()
    logmsg = "Connection Successful"
    logging.debug(logmsg)
    db_cur = db_conn.cursor()
    sql = "delete from ipphones_int"
    try:
        db_cur.execute(sql)
    except:
        e = sys.exc_info()[1]
        ec = sys.exc_info()[0]
        logmsg = "Error Class: %s, Message: %s"
        logging.critical(logmsg, ec, e)
        sys.exit()
    logging.debug("Table ipphone_int empty")
    db_cur.commit()
    return db_conn, db_cur

if __name__ == "__main__":
    cfg = init_env("convert_phone")
    # Connect to Database and clear tables
    conn, cur = connect_db(cfg)
    # Get Files to process:
    scandir = cfg['phone_extracts']['export_path']
    file_str = cfg['phone_extracts']['file_str']
    log_msg = "Scan %s for files containing %s"
    logging.debug(log_msg, scandir, file_str)
    filelist = [file for file in os.listdir(scandir) if file_str in file]
    for file in filelist:
        filename = os.path.join(scandir, file)
        process_extract(filename, cur)
    conn.close()
    logging.info('End Application')
