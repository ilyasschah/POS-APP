using FluentValidation;
using MediatR;

namespace Api.Behaviors;

/// <summary>
/// Runs the FluentValidation validators for each MediatR request.
///
/// BACKGROUND: the solution defines ~150 <c>AbstractValidator</c> classes, but
/// until this behaviour was added nothing ever registered or invoked them — no
/// <c>AddValidatorsFromAssembly</c>, no pipeline behaviour, no <c>IValidator&lt;T&gt;</c>
/// injected anywhere. Every command reached its handler unvalidated, and the
/// <c>ValidationException</c> branch in ExceptionHandlingMiddleware was unreachable.
///
/// ROLLOUT: because those validators have never executed against real traffic,
/// switching straight to enforcement risks rejecting requests the POS currently
/// accepts. So this ships in OBSERVE mode: violations are logged, never thrown.
/// Run normal operations for a few days, review the "VALIDATION would reject"
/// warnings, fix any over-strict rules, then set <c>Validation:Enforce</c> to true
/// (or flip the default below) to begin returning 400s.
/// </summary>
public class ValidationBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    private readonly IEnumerable<IValidator<TRequest>> _validators;
    private readonly ILogger<ValidationBehavior<TRequest, TResponse>> _logger;
    private readonly bool _enforce;

    public ValidationBehavior(
        IEnumerable<IValidator<TRequest>> validators,
        ILogger<ValidationBehavior<TRequest, TResponse>> logger,
        IConfiguration config)
    {
        _validators = validators;
        _logger = logger;
        // Defaults to FALSE — observe only. Set Validation__Enforce=true to enforce.
        _enforce = config.GetValue<bool?>("Validation:Enforce") ?? false;
    }

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (!_validators.Any())
            return await next(cancellationToken);

        var context = new ValidationContext<TRequest>(request);

        var failures = new List<FluentValidation.Results.ValidationFailure>();
        foreach (var validator in _validators)
        {
            var result = await validator.ValidateAsync(context, cancellationToken);
            if (!result.IsValid)
                failures.AddRange(result.Errors);
        }

        if (failures.Count == 0)
            return await next(cancellationToken);

        var summary = string.Join("; ", failures.Select(f => $"{f.PropertyName}: {f.ErrorMessage}"));

        if (_enforce)
        {
            // ExceptionHandlingMiddleware maps this to 400 + { success, message }.
            throw new ValidationException(failures);
        }

        _logger.LogWarning(
            "VALIDATION would reject {RequestType} (observe mode, request allowed through): {Errors}",
            typeof(TRequest).Name, summary);

        return await next(cancellationToken);
    }
}
