using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.PaymentTypeQuery
{
    public class GetAllPaymentTypesQuery : IRequest<List<PaymentTypeDto>>
    {
        public class GetAllPaymentTypesQueryHandler : IRequestHandler<GetAllPaymentTypesQuery, List<PaymentTypeDto>>
        {
            private readonly PaymentTypeRepository _repository;

            public GetAllPaymentTypesQueryHandler(PaymentTypeRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PaymentTypeDto>> Handle(GetAllPaymentTypesQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperPaymentType.MapToPaymentTypeDto).ToList();
            }
        }
    }
}