# Methodology

We assume a web workload that is read-heavy with occasional writes. 
Thus we split the workload across two endpoints:
 - Read-only endpoint intended for anonymous users
 - Write-enabled endpoint intended for 'some' users e.g. admin

All endpoints consume the same SQLite file from the same bucket.
Only the write-enabled Seafowl instance will write to the SQLite db. 
All instances scale to zero.