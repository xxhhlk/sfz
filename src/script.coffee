$ = (sel) -> document.querySelector sel

inputItems = ['text', 'color', 'alpha', 'angle', 'space', 'size']
input = {}

image = $ '#image'
graph = $ '#graph'
refresh = $ '#refresh'
autoRefresh = $ '#auto-refresh'
statusEl = $ '#status'
file = null
canvas = null
textCtx = null
redraw = null

nativeTypes = ['image/png', 'image/jpeg', 'image/gif']
heicTypes = ['image/heic', 'image/heif', 'image/heic-sequence', 'image/heif-sequence']
heicWorker = null
heicSeq = 0
heicPending = {}
loadId = 0


dataURItoBlob = (dataURI) ->
    binStr = atob (dataURI.split ',')[1]
    len = binStr.length
    arr = new Uint8Array len

    for i in [0..len - 1]
        arr[i] = binStr.charCodeAt i
    new Blob [arr], type: 'image/png'


generateFileName = ->
    pad = (n) -> if n < 10 then '0' + n else n

    d = new Date
    '' + d.getFullYear() + '-' + (pad d.getMonth() + 1) + '-' + (pad d.getDate()) + ' ' + \
        (pad d.getHours()) + (pad d.getMinutes()) + (pad d.getSeconds()) + '.png'


setStatus = (text) ->
    statusEl.textContent = text


isHeic = (f) ->
    return true if (f.type or '').toLowerCase() in heicTypes
    /\.(hei[cf]|hif)$/i.test f.name or ''


# HEIC 解码走 Worker，避免大图解码卡住主线程。
# 只在浏览器原生解码失败时才加载，Safari 用户不会下载 wasm。
decodeHeic = (f) ->
    if not heicWorker?
        heicWorker = new Worker 'heic-worker.js'

        heicWorker.onerror = (e) ->
            message = e.message or 'HEIC 解码组件加载失败'
            for id, job of heicPending
                job.reject new Error message
            heicPending = {}
            heicWorker = null

        heicWorker.onmessage = (e) ->
            {id, ok, width, height, pixels, message} = e.data
            job = heicPending[id]
            return if not job?

            delete heicPending[id]
            if ok
                job.resolve {width: width, height: height, pixels: new Uint8ClampedArray pixels}
            else
                job.reject new Error message

    id = ++heicSeq

    new Promise (resolve, reject) ->
        heicPending[id] = {resolve: resolve, reject: reject}

        f.arrayBuffer()
            .then (buffer) ->
                heicWorker.postMessage {id: id, buffer: buffer}, [buffer]
            .catch (err) ->
                delete heicPending[id]
                reject err


mountCanvas = (width, height, paint) ->
    canvas = document.createElement 'canvas'
    canvas.width = width
    canvas.height = height
    textCtx = null

    redraw = ->
        ctx = canvas.getContext '2d'
        ctx.clearRect 0, 0, canvas.width, canvas.height
        paint ctx

    paint canvas.getContext '2d'
    drawText()

    graph.innerHTML = ''
    graph.appendChild canvas

    canvas.addEventListener 'click', -> download()


download = ->
    return if not canvas?

    link = document.createElement 'a'
    link.download = generateFileName()

    blob = dataURItoBlob canvas.toDataURL 'image/png'
    link.href = URL.createObjectURL blob

    graph.appendChild link

    setTimeout ->
        link.click()
        URL.revokeObjectURL link.href
        graph.removeChild link
    , 100


readFile = ->
    return if not file?

    token = ++loadId
    target = file

    setStatus ''

    fileReader = new FileReader

    fileReader.onload = ->
        img = new Image

        img.onload = ->
            return if token isnt loadId
            mountCanvas img.width, img.height, (ctx) -> ctx.drawImage img, 0, 0

        img.onerror = ->
            return if token isnt loadId
            # Chrome / Firefox / Android 无法原生解码 HEIC，回退到 wasm
            if isHeic target
                decodeWithWasm target, token
            else
                alert '无法读取这张图片，请换一张试试'

        img.src = fileReader.result

    fileReader.readAsDataURL target


decodeWithWasm = (target, token) ->
    setStatus '正在解码 HEIC 图片…'

    decodeHeic target
        .then (result) ->
            return if token isnt loadId
            setStatus ''
            mountCanvas result.width, result.height, (ctx) ->
                ctx.putImageData (new ImageData result.pixels, result.width, result.height), 0, 0
        .catch (err) ->
            return if token isnt loadId
            setStatus ''
            alert 'HEIC 解码失败：' + err.message


makeStyle = ->
    match = input.color.value.match /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i

    'rgba(' + (parseInt match[1], 16) + ',' + (parseInt match[2], 16) + ',' \
         + (parseInt match[3], 16) + ',' + input.alpha.value + ')'


drawText = ->
    return if not canvas?
    textSize = input.size.value * Math.max 15, (Math.min canvas.width, canvas.height) / 25

    if textCtx?
        redraw()
    else
        textCtx = canvas.getContext '2d'

    textCtx.save()
    textCtx.translate(canvas.width / 2, canvas.height / 2)
    textCtx.rotate (input.angle.value) * Math.PI / 180

    textCtx.fillStyle = makeStyle()
    textCtx.font = 'bold ' + textSize + 'px -apple-system,"Helvetica Neue",Helvetica,Arial,"PingFang SC","Hiragino Sans GB","WenQuanYi Micro Hei",sans-serif'

    width = (textCtx.measureText input.text.value).width
    step = Math.sqrt (Math.pow canvas.width, 2) + (Math.pow canvas.height, 2)
    margin = (textCtx.measureText '啊').width

    x = Math.ceil step / (width + margin)
    y = Math.ceil (step / (input.space.value * textSize)) / 2

    for i in [-x..x]
        for j in [-y..y]
            textCtx.fillText input.text.value, (width + margin) * i, input.space.value * textSize * j

    textCtx.restore()
    return


image.addEventListener 'change', ->
    file = @files[0]
    return if not file?

    type = (file.type or '').toLowerCase()

    unless type in nativeTypes or isHeic file
        return alert '仅支持 png, jpg, gif, heic 图片格式'

    readFile()


inputItems.forEach (item) ->
    el = $ '#' + item
    input[item] = el

    autoRefresh.addEventListener 'change', ->
        if @checked
            refresh.setAttribute 'disabled', 'disabled'
        else
            refresh.removeAttribute 'disabled'

    el.addEventListener 'input', ->
        drawText() if autoRefresh.checked

    refresh.addEventListener 'click', drawText
