#!/data/workspace_home/jrcaskey/venv/bin/python
import pandas as pd


def parseNames(l):
  l_names = [x.split('.') for x in l]
  l_names = [x[0] for x in l_names]
  l_names = [x.rstrip('\r\n') for x in l_names]
  return l_names
df_checksums = pd.read_csv('Churpek_md5sum.txt.csv')
l1_sums = df_checksums['MD5SUM'].tolist()
l1_names = df_checksums['FILENAME'].tolist()
l1_names = parseNames(l1_names)
df_gensums = pd.read_csv('generated_md5_checksums.csv')
l2_sums = df_gensums['MD5SUM'].tolist()
l2_names = df_gensums['FILENAME'].tolist()
l2_names = parseNames(l2_names)
df_checksums = pd.DataFrame({'MD5SUM' : l1_sums, 'FILENAME': l1_names})
df_gensums = pd.DataFrame({'MD5SUM': l2_sums, 'FILENAME': l2_names})
df_merged = pd.merge(df_checksums, df_gensums, how="outer", on="MD5SUM")
if len(df_merged.loc[df_merged['FILENAME_x'] != df_merged['FILENAME_y'],:].index) == 0:
  print('all files match and are accounted for')
else:
  print('missing or invalid files')
