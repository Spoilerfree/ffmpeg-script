Requisitos:
ffmpeg:
https://www.ffmpeg.org/download.html
 
El script genera una carpeta para los archivos convertidos automaticamente.

INSTRUCCIONES DE USO:

Convert-MKVtoWebMP4.ps1
Convierte archivos .MKV a MP4 H264/AAC optimizado para web
(navegador): faststart, yuv420p, AAC stereo.
- Si el video es > 1080p lo escala a 1080p (usa -Keep4K para evitarlo).
- Selecciona pista de audio en espanol (spa/es/esp).
  Fallback a primera pista si no hay espanol.
- Quema subtitulos .SRT si existe uno con el mismo nombre.
- Para videos 4K usa preset "faster" automaticamente para acelerar.
- Soporte de aceleracion por hardware GPU (NVENC/QSV/AMF) opcional.

Uso:
.\Convert-MKVtoWebMP4.ps1
.\Convert-MKVtoWebMP4.ps1 -InputFolder "D:\Series" -OutputFolder "D:\Web" -CRF 20
.\Convert-MKVtoWebMP4.ps1 -Keep4K              <- no escala a 1080p
.\Convert-MKVtoWebMP4.ps1 -HWAccel nvidia      <- usa GPU NVIDIA (NVENC)
.\Convert-MKVtoWebMP4.ps1 -HWAccel intel       <- usa GPU Intel (QSV)
.\Convert-MKVtoWebMP4.ps1 -HWAccel amd         <- usa GPU AMD (AMF)

Requisitos: ffmpeg.exe y ffprobe.exe en la misma carpeta, o en el PATH.

Convert-MP4toWebMP4.ps1
Re-codifica archivos .MP4 a H264/AAC optimizado para web
(navegador): faststart, yuv420p, AAC stereo.
- Si el video es > 1080p lo escala a 1080p (usa -Keep4K para evitarlo).
- Selecciona pista de audio en espanol (spa/es/esp).
Fallback a primera pista si no hay espanol.
- Quema subtitulos .SRT si existe uno con el mismo nombre.
- Para videos 4K usa preset "faster" automaticamente para acelerar.
- Soporte de aceleracion por hardware GPU (NVENC/QSV/AMF) opcional.

Uso:
.\Convert-MP4toWebMP4.ps1
.\Convert-MP4toWebMP4.ps1 -InputFolder "D:\Videos" -OutputFolder "D:\Web" -CRF 20
.\Convert-MP4toWebMP4.ps1 -Keep4K              <- no escala a 1080p
.\Convert-MP4toWebMP4.ps1 -HWAccel nvidia      <- usa GPU NVIDIA (NVENC)
.\Convert-MP4toWebMP4.ps1 -HWAccel intel       <- usa GPU Intel (QSV)
.\Convert-MP4toWebMP4.ps1 -HWAccel amd         <- usa GPU AMD (AMF)

Requisitos: ffmpeg.exe y ffprobe.exe en la misma carpeta, o en el PATH.


