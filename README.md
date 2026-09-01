# San Catello in realtà aumentata

Sito statico mobile-first per esplorare la statua a colori in 3D e posizionarla nello spazio tramite realtà aumentata.

URL GitHub Pages e destinazione del QR code:

**https://lange99.github.io/test.github.io/**

## Funzionamento

- Il visualizzatore 3D funziona su desktop e smartphone.
- Su Android compatibile usa WebXR o Google Scene Viewer.
- Su iPhone/iPad compatibile usa Apple Quick Look; il file USDZ viene generato dal GLB corretto, quindi il vecchio `statua.usdz` bianco non viene più caricato.
- Il pulsante AR viene mostrato solo quando il dispositivo supporta una modalità disponibile.
- L'AR richiede HTTPS; GitHub Pages lo fornisce automaticamente.

## Asset 3D

L'asset usato dal sito è `statua-ar.glb`:

- texture colore originale incorporata;
- normal map incorporata;
- orientamento verticale nativo, senza rotazioni forzate nella pagina;
- altezza del modello pari a 1 unità/metri nella scena;
- 248.346 triangoli e circa 5 MB, contro i 2.210.778 triangoli e 38,8 MB del tentativo iniziale.

Il file intermedio a colori può essere rigenerato con:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-colored-glb.ps1
```

La versione web è stata poi ottimizzata con [gltfpack / meshoptimizer](https://github.com/zeux/meshoptimizer):

```powershell
gltfpack -i statua-colori.glb -o statua-ar.glb -si 0.12 -sp -se 0.01 -vp 15 -vt 14 -vn 10 -r statua-ar-report.json
```

## QR code

Il QR deve puntare esattamente all'URL GitHub Pages riportato sopra. In questo modo continuerà a funzionare anche dopo futuri aggiornamenti del modello o della pagina.

## Crediti tecnici

Il sito usa [`<model-viewer>`](https://github.com/google/model-viewer) di Google. L'asset è ottimizzato con meshoptimizer, Copyright © 2016–2026 Arseny Kapoulkine, distribuito con licenza MIT.
