using MediatR;
using FluentValidation;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosOrderQuery
{
    public class GetPosOrderByNumberQuery : IRequest<PosOrderDto?>
    {
        public string Number { get; set; } = string.Empty;
        public int CompanyId { get; set; }

        // --- VALIDATOR ---
        public class GetPosOrderByNumberQueryValidator : AbstractValidator<GetPosOrderByNumberQuery>
        {
            public GetPosOrderByNumberQueryValidator()
            {
                RuleFor(x => x.Number)
                    .NotEmpty().WithMessage("Order Number cannot be empty.");
                RuleFor(x => x.CompanyId)
                    .NotEmpty().WithMessage("Company cannot be empty.");
            }
        }

        // --- HANDLER ---
        public class GetPosOrderByNumberQueryHandler : IRequestHandler<GetPosOrderByNumberQuery, PosOrderDto?>
        {
            private readonly PosOrderRepository _repository;

            public GetPosOrderByNumberQueryHandler(PosOrderRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosOrderDto?> Handle(GetPosOrderByNumberQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNumberAsync(request.Number, request.CompanyId);

                if (entity == null)
                    return null;

                return MapperPosOrder.MapToPosOrderDto(entity);
            }
        }
    }
}