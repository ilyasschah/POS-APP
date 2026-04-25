using MediatR;
using FluentValidation;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.CustomerDiscountQuery
{
    public class GetCustomerDiscountByCustomerIdQuery : IRequest<CustomerDiscountDto?>
    {
        public int CustomerId { get; set; }
        public int CompanyId { get; set; }

        public class GetCustomerDiscountByCustomerIdQueryValidator : AbstractValidator<GetCustomerDiscountByCustomerIdQuery>
        {
            public GetCustomerDiscountByCustomerIdQueryValidator()
            {
                RuleFor(x => x.CustomerId).GreaterThan(0).WithMessage("Customer ID is required.");
                RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID is required.");
            }
        }

        public class GetCustomerDiscountByCustomerIdQueryHandler : IRequestHandler<GetCustomerDiscountByCustomerIdQuery, CustomerDiscountDto?>
        {
            private readonly CustomerDiscountRepository _repository;

            public GetCustomerDiscountByCustomerIdQueryHandler(CustomerDiscountRepository repository)
            {
                _repository = repository;
            }

            public async Task<CustomerDiscountDto?> Handle(GetCustomerDiscountByCustomerIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByCustomerIdAsync(request.CustomerId, request.CompanyId);
                if (entity == null) return null;
                return MapperCustomerDiscount.MapToDto(entity);
            }
        }
    }
}