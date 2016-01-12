; docformat = 'rst'

;+
; This file consists of two functions and a main level program
; designed to download MODIS images from `<ftp://ladsftp.nascom.nasa.gov/allData/>`
; using the IDLnetURL object class. 
;
; :Author:
;    Tim Klug
;
; :History:
;    tklug, 3 Dec 2015: initial template
;    tklug, 9 Dec 2015: completed batch processing, error catching, satellite designation
;
; :Copyright:
;    (c) 2015, Tim Klug <tim.klug@uah.edu>
;
;    All rights reserved.
;-

FUNCTION ess_download_modis, imgProd, imgYear, imgDate, imgHgrid, imgVgrid, $
                  dualSat=dsat

;+
; This function formats input parameters into a partial MODIS
;   filename, instantiates a IDLnetURL object, searches directories
;   for an image matching the partial filename, and downloads the
;   image. Recursive calls are enabled to allow for downloading both
;   Aqua and Terra MODIS images.
;
; :Params:
;   imgProd : in, required, type=string
;     the MODIS product name of the image to be downloaded
;   imgYear : in, required, type=integer scalar
;     the year of the MODIS image to be downloaded
;   imgDate : in, required, type=integer scalar
;     the Julian calendar date of the MODIS image to be downloaded
;   imgHgrid : in, required, type=integer scalar
;     the horizontal grid cell of the MODIS image to be downloaded
;   imgVgrid : in, required, type=integer scalar
;     the vertical grid cell of the MODIS image to be downloaded
;     
; :Keywords:
;   dualSat : in, optional, type=integer scalar
;     enables recursive call to ess_download_modis to download
;     additional image from satellite counterpart
; :Uses:
;   ess_download_modis_zerofill
;-

;enable recursion for this function
FORWARD_FUNCTION ess_download_modis

compile_opt idl2

;error catcher:
CATCH, theError
IF theError NE 0 THEN BEGIN
  CATCH, /cancel
  HELP, /LAST_MESSAGE, OUTPUT=errMsg
  print, ''
  print, errMsg
  print, ''
  FOR i=0, N_ELEMENTS(errMsg)-1 DO print, errMsg[i]
  RETURN, !VALUES.F_NAN
ENDIF

IF dsat THEN BEGIN
  alt = (STRMID(imgProd,0,3) EQ 'MOD' ) ? 'MYD' : 'MOD'
  alt = alt + (STRMID(imgProd, 3, STRLEN( imgProd ) ) )
  downloadAlt = ess_download_modis(alt, imgYear, $,
                     imgDate, imgHgrid, imgVgrid, dualSat=0)
ENDIF

;format input parameters as strings and zero−fill
prod = STRUPCASE(imgProd)
year = STRING(imgYear)
date = STRING(imgDate, FORMAT="(I03)")
hInd = STRING(imgHgrid, FORMAT="(I02)")
vInd = STRING(imgVgrid, FORMAT="(I02)")

;build the partial filename
partialFname = STRJOIN(STRSPLIT(prod + '.A' + year + date + '.h' $
  + hInd + 'v' + vInd, /EXTRACT) )

;build url path from filename parameters
urlHost = 'ladsftp.nascom.nasa.gov'
urlPath = STRJOIN(STRSPLIT('allData/5/' + prod + '/' $
  + year + '/' + date + '/', /EXTRACT) )

;instantiate a new IDLnetURL object and connect to the server
oUrl = OBJ_NEW('IDLnetUrl', $
  URL_SCHEME='ftp', $
  FTP_CONNECTION_MODE=0, $
  URL_HOST=urlHost, $
  URL_Port=21, $
  URL_USERNAME='anonymous', $
  URL_PASSWORD='', $
  URL_PATH=urlPath)

CATCH, connectionError
IF connectionError NE 0 THEN BEGIN
  CATCH, /cancel
  ;print, 'Specified file does not exist. Continuing...'
  print, 'Image for date ', date, ',', year, ' does not exist'
  RETURN, !VALUES.F_NAN
ENDIF

;return a directory listing from the current ftp path
result = oUrl->GetFtpDirList(/SHORT)

;search for and store "long" file name of desired image
ind = WHERE(partialFname EQ STRMID(result, 0, STRLEN(partialFName) ), count)
fName = result[ind[0]]


;change directories to the desired file
oUrl->SetProperty, URL_PATH = urlPath + fName

;"get" the file
void = oURL->Get(FILENAME=fName)

;object cleanup
OBJ_DESTROY, oUrl

RETURN, fName

END ; ess_download_modis

;main level program

;define inputs
prod = 'MOD09A1'
year = 2003
jStartDate = 1
jEndDate = 7
hGridInd = 10
vGridInd = 5
ds = 1


;instantiate filename list
hdfList = LIST()

;set counter for failed downloads
failCount = 0

FOR i = jStartDate, jEndDate DO BEGIN
    temp = ess_download_modis(prod, year, LONG(i), hGridInd, vGridInd, dualSat=ds)
    IF TEMP EQ TEMP THEN hdfList->ADD, temp ELSE failCount += 1
ENDFOR

END ; main level program



