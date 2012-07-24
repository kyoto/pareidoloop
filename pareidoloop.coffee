# pinched from http://www.protonfish.com/random.shtml
window.rnd = (mean, stdev) ->
  ((Math.random() * 2 - 1) + (Math.random() * 2 - 1) + (Math.random() * 2 - 1)) * stdev + mean

window.mean = (vals) ->
  total = 0
  $.each(vals, -> total += @)
  total / vals.length

window.stdev = (vals) ->
  if vals.length < 2
    0
  else
    valsMean = mean(vals)
    total = 0
    $.each(vals, -> total += Math.pow((@ - valsMean), 2))
    Math.sqrt(total / (vals.length - 1))


class ShouldMove
  # Move if the new score is higher than the old score
  @simple: (newScore, oldScore) ->
    newScore > oldScore

  # Move if the new score is higher than the old score. Otherwise, use a simulated annealing "temperature" to determine
  # whether or not to move.
  @annealing: (newScore, oldScore) ->
    # if the new state is better, move to it no matter what.
    return true if newScore > oldScore

    # if it's the same, 50/50
    return Math.random() < 0.5 if newScore == oldScore

    # the temperature ranges from 0.01 to 1. The closer we are to the target, the lower the temperature.
    temperature = Math.max(0.01, 1 - (oldScore / @settings.CONFIDENCE_THRESHOLD))

    # The probability we'll move is determined by the difference between the old and new scores, and the current
    # temperature.
    Math.random() < Math.exp((newScore - oldScore) / temperature * 5)


class Quad
  constructor: (@origin, @scale, @alpha, stdDev) ->
    # Create quad with corners on unit square, perturbed by stdDev
    @points = [[rnd(-0.5, stdDev), rnd(-0.5, stdDev)],
               [rnd( 0.5, stdDev), rnd(-0.5, stdDev)],
               [rnd( 0.5, stdDev), rnd( 0.5, stdDev)],
               [rnd(-0.5, stdDev), rnd( 0.5, stdDev)]]

  # Make a random color
  clip: (x, min, max) ->
    Math.min(max, Math.max(min, x))

  draw: (ctx) ->
    ctx.save()
    ctx.translate(@origin[0], @origin[1])
    ctx.scale(@scale, @scale)
    ctx.beginPath()

    ctx.lineTo(@points[i][0], @points[i][1]) for i in [0...4]

    ctx.closePath()

    if @alpha > 0
      ctx.fillStyle = "#ffffff"
      ctx.globalAlpha = @alpha
    else
      ctx.fillStyle = "#000000"
      ctx.globalAlpha = -@alpha

    ctx.fill()
    ctx.restore()


class window.Pareidoloop
  settings: {}

  constructor: (@canvasA, @canvasB, @scoreA, @scoreB) ->
    @canvasOut = document.createElement("canvas")

  start: (args) ->
    @outputCallback = args?.outputCallback
    @shouldMove     = args?.shouldMove ? ShouldMove.annealing

    @settings.BG_COLOR                     = args?.bgColor                   ? "#1e1e1e"
    @settings.BOUNDS_COLOR                 = args?.boundsColor               ? "#00ff00"
    @settings.CANVAS_SIZE                  = args?.canvasSize                ? 50
    # Target confidence threshold
    @settings.CONFIDENCE_THRESHOLD         = args?.confidenceThreshold       ? 30
    @settings.INITIAL_POLYS                = args?.initialPolys              ? 60
    # Max confidence we're ever likely to achieve
    @settings.MAX_CONFIDENCE_THRESHOLD     = args?.maxConfidenceThreshold    ? 35
    @settings.MAX_GENERATIONS              = args?.maxGenerations            ? 6000
    @settings.MAX_GENS_WITHOUT_IMPROVEMENT = args?.maxGensWithoutImprovement ? 1000
    @settings.MAX_POLYS                    = args?.maxPolys                  ? 1000
    @settings.MAX_POLYS_PER_GENERATION     = args?.maxPolysPerGeneration     ? 2
    @settings.OUTPUT_SIZE                  = args?.outputSize                ? 100
    @settings.QUAD_ADD_STDDEV              = args?.quadAddStddev             ? 0.5
    @settings.QUAD_INIT_STDDEV             = args?.quadInitStddev            ? 0.2

    @tickCount = 0
    @ticking = true

    @reset()
    @tick()

  stop: ->
    @ticking = false

  reset: ->
    @initCanvas(@canvasA, @settings.CANVAS_SIZE)
    @clearCanvas(@canvasA)
    @initCanvas(@canvasB, @settings.CANVAS_SIZE)
    @clearCanvas(@canvasB)
    @initCanvas(@canvasOut, @settings.OUTPUT_SIZE)
    @clearCanvas(@canvasOut)

    @scoreA.innerHTML = ""
    @scoreB.innerHTML = ""

    @faceA = new Face([])
    @faceB = null
    @seedCount = @genCount = 0
    @lastImprovedGen = 0
    @seeding = true

  initCanvas: (canvas, size) ->
    canvas.width = canvas.height = size

    # set origin at center
    canvas.getContext("2d").setTransform(1, 0, 0, 1, size / 2, size / 2)

  clearCanvas: (canvas) ->
    ctx = canvas.getContext("2d")
    ctx.fillStyle = @settings.BG_COLOR
    ctx.globalAlpha = 1
    ctx.fillRect(-canvas.width / 2, -canvas.height / 2, canvas.width, canvas.height)

  getSeedFace: ->
    # create a bunch of randomish quads to kick things off
    new Face(new Quad([rnd(0, @settings.CANVAS_SIZE / 10), rnd(-@settings.CANVAS_SIZE / 8, @settings.CANVAS_SIZE / 6)],
                      rnd(@settings.CANVAS_SIZE / 3, @settings.CANVAS_SIZE / 7.5),
                      rnd(0.02, 0.2),
                      @settings.QUAD_INIT_STDDEV) for i in [0...@settings.INITIAL_POLYS])

  tick: ->
    return unless @ticking

    if @seeding
      # spam random polys until ccv gets a false positive
      @faceB = @getSeedFace()
      @seedCount++
      @scoreB.innerHTML = "Searching for seed face: #{@seedCount}"
    else
      # evolve previous generation
      @faceB = @faceA.produceChild()
      @genCount++
      @scoreB.innerHTML = "Generation: #{@genCount}"

    # render new generation
    @clearCanvas(@canvasB)
    @faceB.draw(@canvasB.getContext("2d"))

    # test fitness of new generation
    fitness = @faceB.measureFitness(@canvasB)

    fitnessScore = -999

    if fitness.numFaces == 1 &&
       fitness.bounds.width > @settings.CANVAS_SIZE / 2 && fitness.bounds.height > @settings.CANVAS_SIZE / 2
      # Single face detected (ignore if multiple faces detected) and detected face is large enough
      fitnessScore = fitness.confidence

      if @shouldMove(fitnessScore, @faceA.fitness)
        # new generation replaces previous fittest
        @clearCanvas(@canvasA)
        @faceA = @faceB
        @faceA.draw(@canvasA.getContext("2d"))
        @faceA.drawBounds(@canvasA.getContext("2d"))
        @scoreA.innerHTML = "Fitness: #{fitnessScore.toFixed(6)}, Generation #{@genCount}"

        @seeding = false
        @lastImprovedGen = @genCount

    if (@genCount >= @settings.MAX_GENERATIONS ||
        (@genCount - @lastImprovedGen) > @settings.MAX_GENS_WITHOUT_IMPROVEMENT ||
        fitnessScore > @settings.CONFIDENCE_THRESHOLD)
      # render finished face out as an image

      outCtx = @canvasOut.getContext("2d")
      outScale = @settings.OUTPUT_SIZE / @settings.CANVAS_SIZE
      outCtx.scale(outScale, outScale)
      @faceA.draw(outCtx)

      outputImg = document.createElement("img")
      outputImg.src = @canvasOut.toDataURL()

      @outputCallback(outputImg, @faceA.fitness) if @outputCallback

      # go again
      @reset()

    setTimeout($.proxy(@tick, @), 1)


class Face extends Pareidoloop
  constructor: (@quads) ->
    @fitness = -999
    @bounds =
      x: 0
      y: 0
      width: @settings.CANVAS_SIZE
      height: @settings.CANVAS_SIZE

  produceChild: ->
    childQuads = (@quads[i] for i in [0...@quads.length])

    # Increase prob of removing a poly as we approach max
    if Math.random() * @settings.MAX_POLYS < childQuads.length
      victimIdx = Math.floor(Math.random() * childQuads.length)
      childQuads.splice(victimIdx, 1)
    else
      # center new poly generation on the bounds of the detected face
      newOrigin = [rnd(@bounds.x + @bounds.width  / 2, @bounds.width  / 4),
                    rnd(@bounds.y + @bounds.height / 2, @bounds.height / 4)]

      fitnessDiff = Math.sqrt(Math.max(0, @settings.MAX_CONFIDENCE_THRESHOLD - @fitness))

      # Reduce scale as we approach the target fitness and scale by detected bounds
      newScale = rnd(0.01 + fitnessDiff, 0.02 * @bounds.width)

      # Reduce alpha as we approach the target fitness
      newAlpha = Math.min(1, Math.max(-1, rnd(0, 0.01 + 0.05 * fitnessDiff)))

      childQuads[childQuads.length] = new Quad(newOrigin, newScale, newAlpha, @settings.QUAD_ADD_STDDEV)

    new Face(childQuads)

  draw: (ctx) ->
    @quads[i].draw(ctx) for i in [0...@quads.length]

  drawBounds: (ctx) ->
    ctx.globalAlpha = 1
    ctx.strokeStyle = @settings.BOUNDS_COLOR
    ctx.strokeRect(@bounds.x, @bounds.y, @bounds.width, @bounds.height)

  measureFitness: (canvas) ->
    # ask ccv to do the hard part
    comp = ccv.detect_objects("canvas": canvas, "cascade": cascade, "interval": 5, "min_neighbors": 1)

    if comp.length == 1
      @bounds.x = comp[0].x - canvas.width / 2
      @bounds.y = comp[0].y - canvas.height / 2
      @bounds.width = comp[0].width
      @bounds.height = comp[0].height

      @fitness = comp[0].confidence

    {numFaces: comp.length, bounds: @bounds, confidence: @fitness}

