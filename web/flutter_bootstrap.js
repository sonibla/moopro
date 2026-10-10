{{flutter_js}}
{{flutter_build_config}}

// Drives the pre-Flutter loading ring in index.html. The Flutter-side
// counterpart (lib/widgets/app_startup_loading_screen.dart) uses the same
// size/colors so the hand-off between the two is seamless.
const loading = document.getElementById('loading');
const progressCircle = document.getElementById('progress-circle');
const progressPercentage = document.getElementById('progress-percentage');

let currentProgress = 0;
// Token to prevent overlapping animations from stepping on each other.
let animationId = 0;

// Circle circumference (2 * π * r) for the stroke-dashoffset progress.
const radius = 50;
const circumference = 2 * Math.PI * radius;

progressCircle.style.strokeDasharray = circumference;
progressCircle.style.strokeDashoffset = circumference;

function renderProgress(value) {
    progressCircle.style.strokeDashoffset = circumference - (value / 100) * circumference;
    progressPercentage.textContent = Math.round(value) + '%';
}

// Animates the ring and percentage together; never moves backwards.
function animateProgress(targetProgress) {
    const duration = 1200;
    animationId += 1;
    const thisAnimationId = animationId;
    const startProgress = currentProgress;
    targetProgress = Math.max(targetProgress, currentProgress);

    if (targetProgress <= startProgress) {
        renderProgress(currentProgress);
        return;
    }

    const progressDiff = targetProgress - startProgress;
    const startTime = performance.now();

    function updateProgress(currentTime) {
        if (thisAnimationId !== animationId) {
            return;
        }
        const t = Math.max(0, Math.min((currentTime - startTime) / duration, 1));
        const eased = 1 - Math.pow(1 - t, 2); // ease-out quadratic
        currentProgress = Math.max(startProgress, startProgress + progressDiff * eased);
        renderProgress(currentProgress);

        if (t < 1) {
            requestAnimationFrame(updateProgress);
        } else {
            currentProgress = targetProgress;
            renderProgress(currentProgress);
        }
    }

    requestAnimationFrame(updateProgress);
}

function updateProgressStage(step) {
    const targets = { initial: 15, entrypoint: 45, engine: 85, app: 98, complete: 100 };
    animateProgress(targets[step] ?? 0);
}

updateProgressStage('initial');

_flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
        updateProgressStage('entrypoint');

        // Brief delay so the progress transition is visible.
        await new Promise(resolve => setTimeout(resolve, 300));

        updateProgressStage('engine');
        const appRunner = await engineInitializer.initializeEngine();

        updateProgressStage('app');
        await appRunner.runApp();

        updateProgressStage('complete');

        // Let the final animation finish and Flutter render, then fade out.
        setTimeout(() => {
            loading.classList.add('fade-content');
            setTimeout(() => {
                loading.style.display = 'none';
            }, 300);
        }, 600);
    }
});
