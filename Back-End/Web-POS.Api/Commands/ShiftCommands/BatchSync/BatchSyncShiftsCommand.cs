using FluentValidation;
using MediatR;
using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Commands.ShiftCommands.BatchSync;

public class BatchSyncShiftsCommand : IRequest<BatchSyncShiftsResponse>
{
    public BatchSyncShiftsRequest Request { get; }
    public int CompanyId { get; }

    public BatchSyncShiftsCommand(BatchSyncShiftsRequest request, int companyId)
    {
        Request = request;
        CompanyId = companyId;
    }

    public class Validator : AbstractValidator<BatchSyncShiftsCommand>
    {
        public Validator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0);
            RuleFor(x => x.Request.Shifts)
                .NotNull()
                .Must(s => s.Count > 0).WithMessage("Batch must contain at least one shift.");
            RuleForEach(x => x.Request.Shifts)
                .ChildRules(s =>
                {
                    s.RuleFor(x => x.LocalId).NotEmpty();
                    s.RuleFor(x => x.UserId).GreaterThan(0);
                    s.RuleFor(x => x.StartingCash).GreaterThanOrEqualTo(0);
                });
        }
    }

    public class Handler : IRequestHandler<BatchSyncShiftsCommand, BatchSyncShiftsResponse>
    {
        private readonly ShiftRepository _repository;
        private readonly ILogger<Handler> _logger;

        public Handler(ShiftRepository repository, ILogger<Handler> logger)
        {
            _repository = repository;
            _logger = logger;
        }

        public async Task<BatchSyncShiftsResponse> Handle(
            BatchSyncShiftsCommand command,
            CancellationToken cancellationToken)
        {
            var response = new BatchSyncShiftsResponse();

            foreach (var dto in command.Request.Shifts)
            {
                try
                {
                    Shift? existing = dto.ServerId.HasValue && dto.ServerId > 0
                        ? await _repository.GetByIdAsync(dto.ServerId.Value)
                        : null;

                    if (existing is not null)
                    {
                        existing.SyncFrom(dto.OpenedAt, dto.ClosedAt, dto.StartingCash, dto.ActualEndingCash, dto.Status);
                        await _repository.UpdateAsync(existing);
                        response.UpdatedCount++;
                        response.Results.Add(new SyncedShiftResult { LocalId = dto.LocalId, ServerId = existing.Id });
                    }
                    else
                    {
                        var newShift = Shift.Create(command.CompanyId, dto.UserId, dto.StartingCash);
                        newShift.SyncFrom(dto.OpenedAt, dto.ClosedAt, dto.StartingCash, dto.ActualEndingCash, dto.Status);
                        await _repository.AddAsync(newShift);
                        response.InsertedCount++;
                        response.Results.Add(new SyncedShiftResult { LocalId = dto.LocalId, ServerId = newShift.Id });
                    }

                    response.SyncedCount++;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "BatchSync failed for shift [LocalId={LocalId}]", dto.LocalId);
                    response.Errors.Add($"Shift [{dto.LocalId}]: {ex.Message}");
                }
            }

            return response;
        }
    }
}
