using MediatR;
using FluentValidation;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosOrderQuery
{
    public class GetPosOrderByIdQuery : IRequest<PosOrderDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        // --- VALIDATOR ---
        public class GetPosOrderByIdQueryValidator : AbstractValidator<GetPosOrderByIdQuery>
        {
            public GetPosOrderByIdQueryValidator()
            {
                RuleFor(x => x.Id)
                    .GreaterThan(0).WithMessage("Order ID must be greater than zero.");
                RuleFor(x => x.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be greater than zero.");
            }
        }

        // --- HANDLER ---
        public class GetPosOrderByIdQueryHandler : IRequestHandler<GetPosOrderByIdQuery, PosOrderDto?>
        {
            private readonly PosOrderRepository _repository;

            public GetPosOrderByIdQueryHandler(PosOrderRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosOrderDto?> Handle(GetPosOrderByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);

                if (entity == null)
                    return null;

                return MapperPosOrder.MapToPosOrderDto(entity);
            }
        }
    }
}