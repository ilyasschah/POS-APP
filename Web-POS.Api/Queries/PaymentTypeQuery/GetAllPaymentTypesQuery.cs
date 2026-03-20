using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PaymentTypeQuery
{
    public class GetAllPaymentTypesQuery : IRequest<List<PaymentTypeDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllPaymentTypesQueryHandler : IRequestHandler<GetAllPaymentTypesQuery, List<PaymentTypeDto>>
        {
            private readonly PaymentTypeRepository _repository;

            public GetAllPaymentTypesQueryHandler(PaymentTypeRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PaymentTypeDto>> Handle(GetAllPaymentTypesQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync(request.CompanyId);
                return entities.Select(MapperPaymentType.MapToPaymentTypeDto).ToList();
            }
        }
    }
    public class GetAllPaymentTypesQueryValidator : AbstractValidator<GetAllPaymentTypesQuery>
    {
        public GetAllPaymentTypesQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}