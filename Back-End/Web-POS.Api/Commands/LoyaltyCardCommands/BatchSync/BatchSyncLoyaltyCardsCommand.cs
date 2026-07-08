// FILE: Products.Api.Commands\LoyaltyCardCommands\BatchSync\BatchSyncLoyaltyCardsCommand.cs

using FluentValidation;
using MediatR;
using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Commands.LoyaltyCardCommands.BatchSync;

public class BatchSyncLoyaltyCardsCommand : IRequest<BatchSyncLoyaltyCardsResponse>
{
    public BatchSyncLoyaltyCardsRequest Request { get; }
    public int CompanyId { get; }

    public BatchSyncLoyaltyCardsCommand(BatchSyncLoyaltyCardsRequest request, int companyId)
    {
        Request = request;
        CompanyId = companyId;
    }

    public class Validator : AbstractValidator<BatchSyncLoyaltyCardsCommand>
    {
        public Validator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0);
            RuleFor(x => x.Request.Cards)
                .NotNull()
                .Must(c => c.Count > 0).WithMessage("Batch must contain at least one card.");
            RuleForEach(x => x.Request.Cards)
                .ChildRules(card =>
                {
                    card.RuleFor(c => c.CustomerId).GreaterThan(0);
                    card.RuleFor(c => c.Points).GreaterThanOrEqualTo(0);
                });
        }
    }

    public class Handler : IRequestHandler<BatchSyncLoyaltyCardsCommand, BatchSyncLoyaltyCardsResponse>
    {
        private readonly LoyaltyCardRepository _repository;
        private readonly ILogger<Handler> _logger;

        public Handler(LoyaltyCardRepository repository, ILogger<Handler> logger)
        {
            _repository = repository;
            _logger = logger;
        }

        public async Task<BatchSyncLoyaltyCardsResponse> Handle(
            BatchSyncLoyaltyCardsCommand command,
            CancellationToken cancellationToken)
        {
            var response = new BatchSyncLoyaltyCardsResponse();

            // OFFLINE-FIRST: No outer transaction. One bad card must not roll back the rest.
            foreach (var dto in command.Request.Cards)
            {
                try
                {
                    var existing = await _repository.GetByIdOrCardNumberAsync(dto.Id, dto.CardNumber);

                    if (existing is not null)
                    {
                        // Overwrite — the tablet is the source of truth for points.
                        existing.SyncFrom(dto.CardNumber, dto.Points);
                        await _repository.UpdateAsync(existing);
                        response.UpdatedCount++;
                    }
                    else
                    {
                        var newCard = LoyaltyCard.Create(
                            companyId: command.CompanyId,
                            customerId: dto.CustomerId,
                            cardNumber: dto.CardNumber,
                            points: dto.Points);

                        await _repository.AddAsync(newCard);
                        response.InsertedCount++;
                    }

                    response.SyncedCount++;
                }
                catch (Exception ex)
                {
                    var identifier = dto.CardNumber ?? dto.Id?.ToString() ?? $"CustomerId={dto.CustomerId}";
                    _logger.LogError(ex, "BatchSync failed for loyalty card [{Card}]", identifier);
                    response.Errors.Add($"Card [{identifier}]: {ex.Message}");
                }
            }

            return response;
        }
    }
}
