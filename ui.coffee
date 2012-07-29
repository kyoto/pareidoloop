$ ->
  inputImageSize = document.getElementById("input-image-size")
  inputTargetFitness = document.getElementById("input-target-fitness")
  inputMaxGens = document.getElementById("input-max-gens")
  inputButton = document.getElementById("input-button")
  running = false
  fitnesses = []
  genCounts = []
  seedCounts = []
  pareidoloop = new Pareidoloop($("#canvasA")[0], $("#canvasB")[0], $("#scoreA")[0], $("#scoreB")[0])

  inputButton.onclick = ->
    if running
      pareidoloop.stop()
      running = false
      inputButton.innerHTML = "commence"
    else
      go = true

      imageSize = parseInt(inputImageSize.value)
      if isNaN(imageSize) || imageSize < 1
        inputImageSize.style.borderColor = "#f00"
        go = false
      else
        inputImageSize.style.borderColor = "#000"

      targetFitness = parseFloat(inputTargetFitness.value)
      if isNaN(targetFitness) || targetFitness <= 0 || targetFitness > 35
        inputTargetFitness.style.borderColor = "#f00"
        go = false
      else
        inputTargetFitness.style.borderColor = "#000"

      maxGens = parseInt(inputMaxGens.value)
      if isNaN(maxGens) || maxGens <= 0
        inputMaxGens.style.borderColor = "#f00"
        go = false
      else
        inputMaxGens.style.borderColor = "#000"

      if go
        pareidoloop.start(outputCallback: renderImage, outputSize: imageSize, confidenceThreshold: targetFitness, maxGenerations: maxGens)
        inputButton.innerHTML = "cease"
        running = true


  renderImage = (image, fitness) ->
    fitnesses.push(fitness)
    genCounts.push(pareidoloop.genCount)
    seedCounts.push(pareidoloop.seedCount)
    $("#fitness-mean").text(mean(fitnesses).toFixed(4))
    $("#fitness-stdev").text(stdev(fitnesses).toFixed(2))
    $("#generations-mean").text(mean(genCounts).toFixed(1))
    $("#generations-stdev").text(stdev(genCounts).toFixed(2))
    $("#seeds-mean").text(mean(seedCounts).toFixed(1))
    $("#seeds-stdev").text(stdev(seedCounts).toFixed(2))

    title = fitnesses.length + ". Fitness: " + fitness.toFixed(4) + ", Generation " + pareidoloop.genCount
    $(image).appendTo($("#output")).attr("title",  title)

    anchor = $('<a href="' + image.src + '" target="_blank"></a>')
    size = inputImageSize.value
    anchor.attr("download", "face-" + size + "x" + size + "-" + $("#output img").length + ".png")
    $(image).wrap(anchor)

    anchor.appendTo($("body"))[0].click() if $("#save-checkbox").prop("checked")
